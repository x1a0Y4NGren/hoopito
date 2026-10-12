import * as THREE from 'three';
import { gsap } from 'gsap';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';
import { CopyShader } from 'three/addons/shaders/CopyShader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { createCourtHardware } from './court-hardware';
import { createCourtFloor } from './court-floor';
import { loadCourtTextures } from './court-textures';
import { storyPose } from './story-pose';
import { preparedDrawCost } from './gpu-calibration';
import { ShotContinuation } from './scene-contract';
import {
  ActiveFrameMonitor,
  renderDensity,
  sceneRenderRoute,
  shouldRenderContinuously,
} from './scene-performance';
import type {
  CourtPoint,
  CourtScene,
  CourtSceneOptions,
  StoryFrame,
  SceneQuality,
} from './scene-contract';
import {
  courtVertex,
  courtFragment,
  trailVertex,
  trailFragment,
} from './shaders/court';

const WIDTH = 15;
const LENGTH = 14;
const RIM = new THREE.Vector3(0, 3.05, -5.3);
const AMBER = new THREE.Color('#FF5A1F');
const clamp = (value: number) => THREE.MathUtils.clamp(value, 0, 1);
const worldPoint = (point: CourtPoint) =>
  new THREE.Vector3(
    (clamp(point.x) - 0.5) * WIDTH,
    0.018,
    (clamp(point.y) - 0.5) * LENGTH,
  );

/** No imported models or remote assets. The page owns input eligibility and score. */
export async function createCourtScene(
  canvas: HTMLCanvasElement,
  options: CourtSceneOptions,
): Promise<CourtScene> {
  if (options.signal.aborted)
    throw new DOMException('Scene aborted', 'AbortError');

  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#0B0D0F');
  scene.fog = new THREE.FogExp2('#0B0D0F', 0.018);
  const camera = new THREE.PerspectiveCamera(32, 1, 0.015, 100);
  const disposables = new Set<{ dispose(): void }>();
  let renderer: THREE.WebGLRenderer | undefined;
  let composer: EffectComposer | undefined;
  let animationFrame = 0;
  let disposed = false;
  let paused = false;
  let failed = false;
  let ready = false;
  let motionEnabled = options.motionEnabled;
  let quality: SceneQuality = 'full';
  let frame: StoryFrame = { chapter: 'hero', progress: 0, active: true };
  let flight: gsap.core.Timeline | undefined;
  const shotContinuation = new ShotContinuation();
  let introduction: gsap.core.Tween | undefined;
  let trail: THREE.Mesh<THREE.TubeGeometry, THREE.ShaderMaterial> | undefined;
  const monitor = new ActiveFrameMonitor();
  let renderCount = 0;
  let changingUntil = 0;
  const intro = { progress: motionEnabled ? 0 : 1 };
  const aim = new THREE.Vector3();
  const pointer = new THREE.Vector2();
  const raycaster = new THREE.Raycaster();
  const floorPlane = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
  const intersection = new THREE.Vector3();

  const own = <T extends { dispose(): void }>(resource: T): T => {
    if (disposed) {
      resource.dispose();
      return resource;
    }
    disposables.add(resource);
    return resource;
  };
  const add = <T extends THREE.Object3D>(
    object: T,
    parent: THREE.Object3D = scene,
  ): T => {
    parent.add(object);
    return object;
  };
  const material = (parameters: THREE.MeshStandardMaterialParameters) =>
    own(new THREE.MeshStandardMaterial(parameters));
  const box = (
    size: [number, number, number],
    position: [number, number, number],
    surface: THREE.Material,
    parent: THREE.Object3D = scene,
  ) => {
    const mesh = add(
      new THREE.Mesh(own(new THREE.BoxGeometry(...size)), surface),
      parent,
    );
    mesh.position.set(...position);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    return mesh;
  };
  const fail = (reason: 'context-lost' | 'performance' | 'initialization') => {
    if (disposed || failed) return;
    failed = true;
    dispose();
    options.onFailure(reason);
  };
  const onContextLost = (event: Event) => {
    event.preventDefault();
    fail('context-lost');
  };
  const onAbort = () => dispose();

  function dispose() {
    if (disposed) return;
    disposed = true;
    cancelAnimationFrame(animationFrame);
    introduction?.kill();
    shotContinuation.cancel();
    removeTrail();
    canvas.removeEventListener('pointerup', onPointerUp);
    canvas.removeEventListener('webglcontextlost', onContextLost);
    window.removeEventListener('resize', resize);
    resizeObserver?.disconnect();
    resolutionQuery?.removeEventListener('change', onResolutionChange);
    options.signal.removeEventListener('abort', onAbort);
    for (const resource of disposables) resource.dispose();
    disposables.clear();
    composer?.dispose();
    renderer?.dispose();
    scene.clear();
    delete canvas.dataset.sceneReady;
    canvas.dataset.rendering = 'off';
  }

  // Declared before setup so cancellation also works during shader compilation.
  let bloom: UnrealBloomPass | undefined;
  let fallbackAA: ShaderPass | undefined;
  let scenePass: AntialiasedScenePass | undefined;
  let supportedSamples: number[] = [];
  let nativeSamples = 0;
  let resolutionQuery: MediaQueryList | undefined;
  let paint: THREE.ShaderMaterial | undefined;
  let selection: THREE.Group | undefined;
  let madeMarker: THREE.Group | undefined;
  let ball: THREE.Group | undefined;
  let idleBall: THREE.Group | undefined;
  let keyLight: THREE.SpotLight | undefined;
  let macroLight: THREE.SpotLight | undefined;
  let orangeRimLight: THREE.SpotLight | undefined;
  let hardware: ReturnType<typeof createCourtHardware> | undefined;
  let courtFloor: ReturnType<typeof createCourtFloor> | undefined;
  const desiredCamera = new THREE.Vector3();
  const desiredTarget = new THREE.Vector3();
  let resizeObserver: ResizeObserver | undefined;

  function requestRender() {
    if (
      !disposed &&
      !paused &&
      ready &&
      frame.active &&
      frame.chapter !== 'download' &&
      !animationFrame
    )
      animationFrame = requestAnimationFrame(render);
  }

  function monitorResolution() {
    resolutionQuery?.removeEventListener('change', onResolutionChange);
    resolutionQuery = matchMedia(
      `(resolution: ${window.devicePixelRatio || 1}dppx)`,
    );
    resolutionQuery.addEventListener('change', onResolutionChange);
  }

  function onResolutionChange() {
    if (disposed) return;
    monitorResolution();
    resize();
  }

  function resize() {
    if (disposed || !renderer || !composer) return;
    const width = Math.max(1, canvas.clientWidth || window.innerWidth);
    const height = Math.max(1, canvas.clientHeight || window.innerHeight);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    // The element is the actual right-hand stage, rather than a clipped full-screen buffer.
    const pixelRatio = renderDensity(
      window.devicePixelRatio || 1,
      quality,
      width,
      height,
    );
    // Retina already supplies four physical pixels per CSS pixel. Select the
    // supported sample count again when zoom or a move between displays changes density.
    const sampleLimit = pixelRatio >= 1.5 ? 2 : 4;
    const samples = Math.max(
      0,
      ...supportedSamples.filter((value) => value >= 2 && value <= sampleLimit),
    );
    if (scenePass && scenePass.target.samples !== samples) {
      scenePass.target.dispose();
      scenePass.target.samples = samples;
    }
    if (fallbackAA) fallbackAA.enabled = samples === 0;
    const route = sceneRenderRoute(quality, nativeSamples);
    canvas.dataset.pipeline = route;
    canvas.dataset.antialias =
      route === 'direct'
        ? `native-msaa-${nativeSamples}`
        : samples
          ? `msaa-${samples}`
          : 'fxaa';
    renderer.setPixelRatio(pixelRatio);
    renderer.setSize(width, height, false);
    composer.setPixelRatio(renderer.getPixelRatio());
    composer.setSize(width, height);
    // Bloom is deliberately soft; its blur buffers need not match the sharp scene's Retina resolution.
    const bloomScale = Math.min(
      1,
      (quality === 'full' ? 720 : 360) / (width * pixelRatio),
    );
    bloom?.setSize(
      width * pixelRatio * bloomScale,
      height * pixelRatio * bloomScale,
    );
    fallbackAA?.uniforms.resolution.value.set(
      1 / (width * pixelRatio),
      1 / (height * pixelRatio),
    );
    canvas.dataset.pixelRatio = pixelRatio.toFixed(2);
    canvas.dataset.bufferWidth = String(Math.round(width * pixelRatio));
    canvas.dataset.bufferHeight = String(Math.round(height * pixelRatio));
    monitor.reset();
    updateCamera();
    requestRender();
  }

  function updateCamera() {
    const pose = storyPose(frame, motionEnabled);
    desiredCamera.set(...pose.position);
    desiredTarget.set(...pose.target);
    // The opening stays a macro composition: a gentle focus approach ends at hero progress zero.
    if (frame.chapter === 'hero' && frame.progress === 0 && intro.progress < 1)
      desiredCamera.addScaledVector(
        new THREE.Vector3(0.05, 0.012, 0.06),
        1 - intro.progress,
      );
    camera.position.copy(desiredCamera);
    aim.copy(desiredTarget);
    camera.lookAt(aim);
    if (camera.fov !== pose.fov) {
      camera.fov = pose.fov;
      camera.updateProjectionMatrix();
    }
    camera.updateMatrixWorld();
    if (paint) paint.uniforms.uReveal!.value = pose.reveal;
    if (keyLight) keyLight.intensity = 130 * pose.light;
    if (orangeRimLight) orangeRimLight.intensity = 125 * pose.light;
    if (macroLight)
      macroLight.intensity = 1.45 * (0.82 + intro.progress * 0.18);
    scene.environmentIntensity = 0.1 * pose.light;
    courtFloor?.setLight(pose.light);
    // A cinematic cutaway lets the overhead camera read the floor without roof hardware crossing it.
    hardware?.setCeilingVisibility(
      1 - THREE.MathUtils.smoothstep(camera.position.y, 6.8, 7.8),
    );
  }

  function onPointerUp(event: PointerEvent) {
    if (
      disposed ||
      paused ||
      event.button !== 0 ||
      !frame.active ||
      frame.chapter !== 'experience'
    )
      return;
    const bounds = canvas.getBoundingClientRect();
    pointer.set(
      ((event.clientX - bounds.left) / bounds.width) * 2 - 1,
      (-(event.clientY - bounds.top) / bounds.height) * 2 + 1,
    );
    raycaster.setFromCamera(pointer, camera);
    if (!raycaster.ray.intersectPlane(floorPlane, intersection)) return;
    const x = intersection.x / WIDTH + 0.5;
    const y = intersection.z / LENGTH + 0.5;
    if (x >= 0.02 && x <= 0.98 && y >= 0.04 && y <= 0.98)
      options.onPoint({ x, y });
  }

  function applyQuality(nextQuality: SceneQuality) {
    if (quality === nextQuality || disposed) return;
    quality = nextQuality;
    if (bloom) bloom.enabled = quality === 'full';
    if (trail) trail.visible = quality === 'full';
    canvas.dataset.quality = quality;
    options.onQualityChange?.(quality);
    resize();
  }

  function drawFrame() {
    if (!renderer || !composer) return;
    if (sceneRenderRoute(quality, nativeSamples) === 'direct') {
      // Default RGBA8 framebuffer applies ACES and sRGB in the material shaders.
      // Native MSAA retains sharp silhouettes without HDR resolves or fullscreen copies.
      renderer.setRenderTarget(null);
      renderer.render(scene, camera);
    } else {
      composer.render();
    }
  }

  function render(now: number) {
    animationFrame = 0;
    if (disposed || paused || !ready || !renderer || !composer) return;
    if (!frame.active || frame.chapter === 'download') {
      canvas.dataset.rendering = 'off';
      monitor.reset();
      return;
    }
    try {
      updateCamera();
      renderer.info.reset();
      drawFrame();
      renderCount += 1;
      canvas.dataset.renderCount = String(renderCount);
      canvas.dataset.drawCalls = String(renderer.info.render.calls);
      canvas.dataset.triangles = String(renderer.info.render.triangles);
    } catch {
      fail('initialization');
      return;
    }

    // Newly created GSAP tweens can await their first tick before isActive() becomes true.
    // Treat a pending introduction/shot as active as well, so there is no transient idle frame.
    const moving =
      intro.progress < 1 ||
      Boolean(introduction?.isActive() || (flight && !flight.paused())) ||
      now < changingUntil;
    const continuous = shouldRenderContinuously({
      ...frame,
      paused,
      motionEnabled,
      moving,
    });
    canvas.dataset.rendering = continuous ? 'active' : 'idle';
    const sample = monitor.observe(now, continuous);
    if (sample) {
      canvas.dataset.frameMs = sample.average.toFixed(2);
      canvas.dataset.frameP95 = sample.p95.toFixed(2);
      canvas.dataset.fps = (1000 / sample.average).toFixed(1);
      if (sample.changed) applyQuality(sample.quality);
    }
    if (continuous) requestRender();
  }

  options.signal.addEventListener('abort', onAbort, { once: true });
  canvas.addEventListener('webglcontextlost', onContextLost, {
    passive: false,
  });

  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      // Lower quality tiers draw directly to the native antialiased RGBA8 canvas.
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
      outputBufferType: THREE.UnsignedByteType,
    });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.9;
    renderer.shadowMap.enabled = true;
    // Lights and court hardware are static. Rebuild their shadow only when the animated ball changes.
    renderer.shadowMap.autoUpdate = false;
    renderer.shadowMap.needsUpdate = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.setClearColor('#0B0D0F', 1);
    renderer.debug.onShaderError = () => fail('initialization');
    renderer.info.autoReset = false;
    // Three r186 creates a WebGL2 context; the installed declarations also retain the legacy union.
    const gl = renderer.getContext() as WebGL2RenderingContext;
    nativeSamples = gl.getContextAttributes()?.antialias
      ? Number(gl.getParameter(gl.SAMPLES))
      : 0;
    canvas.dataset.nativeSamples = String(nativeSamples);
    const debug = gl.getExtension('WEBGL_debug_renderer_info');
    canvas.dataset.renderer = debug
      ? String(gl.getParameter(debug.UNMASKED_RENDERER_WEBGL))
      : String(gl.getParameter(gl.RENDERER));
    canvas.dataset.quality = quality;

    const textures = await loadCourtTextures(options.signal, own);
    if (disposed || options.signal.aborted)
      throw new DOMException('Scene aborted', 'AbortError');
    for (const texture of Object.values(textures)) {
      texture.anisotropy = Math.min(
        8,
        renderer.capabilities.getMaxAnisotropy(),
      );
    }

    const pmrem = new THREE.PMREMGenerator(renderer);
    const room = new RoomEnvironment();
    const environment = own(pmrem.fromScene(room, 0.04));
    scene.environment = environment.texture;
    scene.environmentIntensity = 0.1;
    room.dispose();
    pmrem.dispose();

    const emissiveAmber = material({
      color: AMBER,
      emissive: AMBER,
      emissiveIntensity: 1.9,
      toneMapped: true,
    });
    const blue = material({
      color: '#437AF4',
      emissive: '#437AF4',
      emissiveIntensity: 0.28,
    });
    const red = material({
      color: '#F06959',
      emissive: '#F06959',
      emissiveIntensity: 0.28,
    });

    add(new THREE.HemisphereLight('#BDCCD7', '#060504', 0.14));
    keyLight = add(new THREE.SpotLight('#FFF0DF', 130, 48, 0.45, 0.78, 1.8));
    keyLight.position.set(4, 10, 1);
    keyLight.target.position.set(0, 0, -2);
    add(keyLight.target);
    keyLight.castShadow = true;
    keyLight.shadow.mapSize.set(1024, 1024);
    keyLight.shadow.bias = -0.00035;
    keyLight.shadow.normalBias = 0.035;
    keyLight.shadow.camera.near = 1;
    keyLight.shadow.camera.far = 29;
    own(keyLight.shadow);
    orangeRimLight = add(
      new THREE.SpotLight('#DE783F', 125, 40, 0.68, 0.85, 1.8),
    );
    orangeRimLight.position.set(-5, 7.9, -7);
    orangeRimLight.target.position.set(0, 2, -3);
    add(orangeRimLight.target);
    const coolLight = add(new THREE.PointLight('#A7BBC7', 38, 20, 2));
    coolLight.position.set(7, 5, 5);
    // The macro ball is lit by the same warm sideline direction as the arena.
    macroLight = add(new THREE.SpotLight('#FFE4BE', 1.45, 3.6, 0.72, 0.7, 2));
    macroLight.position.set(3.5, 0.72, 3.6);
    macroLight.target.position.set(2.6, 0.13, 4.1);
    add(macroLight.target);
    const ballRim = add(new THREE.PointLight('#CE692D', 1.1, 2.2, 2));
    ballRim.position.set(2.05, 0.2, 3.76);

    // Continuous flooring, acoustic walls and ceiling luminaires establish an indoor court.
    // The floor has no exposed miniature-model edge in the pullback or overhead shots.
    // Matte acoustic walls carry the ambient base finish; no view-dependent BRDF
    // is visible here. Their contour lights remain separate emissive geometry.
    const wall = own(new THREE.MeshBasicMaterial({ color: '#090E11' }));
    box([27, 9, 0.24], [0, 4.4, -13.5], wall);
    box([0.22, 8.8, 36], [-13.5, 4.3, 2], wall);
    box([0.22, 8.8, 36], [13.5, 4.3, 2], wall);
    box([26.8, 0.034, 0.045], [0, 0.48, -13.34], emissiveAmber);

    courtFloor = createCourtFloor({ own, mapleMap: textures.maple, rim: RIM });
    add(courtFloor.mesh);
    const contactShadow = own(
      new THREE.ShaderMaterial({
        uniforms: { uOpacity: { value: 0.66 } },
        vertexShader: courtVertex,
        fragmentShader: /* glsl */ `varying vec2 vUv;
        uniform float uOpacity;
        void main() {
          float distance = length((vUv - 0.5) * 2.0);
          float alpha = exp(-distance * distance * 5.5) * (1.0 - smoothstep(0.72, 1.0, distance));
          gl_FragColor = vec4(0.015, 0.012, 0.009, alpha * uOpacity);
          #include <tonemapping_fragment>
          #include <colorspace_fragment>
        }`,
        transparent: true,
        depthWrite: false,
        toneMapped: true,
      }),
    );
    const ballContact = add(
      new THREE.Mesh(own(new THREE.PlaneGeometry(0.48, 0.44)), contactShadow),
    );
    ballContact.rotation.x = -Math.PI / 2;
    ballContact.position.set(2.6, 0.008, 4.1);
    paint = own(
      new THREE.ShaderMaterial({
        uniforms: { uReveal: { value: 0 } },
        vertexShader: courtVertex,
        fragmentShader: courtFragment,
        transparent: true,
        depthWrite: false,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        toneMapped: true,
      }),
    );
    const lines = add(
      new THREE.Mesh(own(new THREE.PlaneGeometry(WIDTH, LENGTH)), paint),
    );
    lines.rotation.x = -Math.PI / 2;
    lines.position.y = 0.012;
    const keyWash = add(
      new THREE.Mesh(
        own(new THREE.PlaneGeometry(4.9, 5.8)),
        own(
          new THREE.MeshBasicMaterial({
            color: '#27211B',
            transparent: true,
            opacity: 0.32,
            depthWrite: false,
          }),
        ),
      ),
    );
    keyWash.rotation.x = -Math.PI / 2;
    keyWash.position.set(0, 0.009, -4.1);
    box([0.055, 0.035, 14], [-7.58, 0.01, 0], blue);
    box([0.055, 0.035, 14], [7.58, 0.01, 0], red);

    hardware = createCourtHardware({
      own,
      metalMap: textures.metal,
      glassMap: textures.glass,
      rim: RIM,
    });
    add(hardware.group);

    const leather =
      'leather' in textures
        ? (textures.leather as THREE.Texture)
        : own(makeLeatherTexture());
    const leatherDetail =
      'leatherDetail' in textures
        ? (textures.leatherDetail as THREE.Texture)
        : own(leather.clone());
    leather.colorSpace = THREE.SRGBColorSpace;
    leather.repeat.set(4, 2);
    leatherDetail.colorSpace = THREE.NoColorSpace;
    leatherDetail.repeat.set(4, 2);
    const ballSurface = material({
      color: '#DDBD97',
      map: leather,
      bumpMap: leatherDetail,
      bumpScale: 0.00032,
      roughness: 0.73,
      metalness: 0.015,
    });
    // Surface channels, antialiased in screen space, keep the ball silhouette round.
    // Modelling these as exposed tubes made close-ups look like cables wrapped round a ball.
    ballSurface.customProgramCacheKey = () => 'hooptrace-leather-channels-v2';
    ballSurface.onBeforeCompile = (shader) => {
      shader.vertexShader = shader.vertexShader
        .replace(
          '#include <common>',
          '#include <common>\nvarying vec3 vBallSurface;',
        )
        .replace(
          '#include <begin_vertex>',
          '#include <begin_vertex>\nvBallSurface = normalize(position);',
        );
      shader.fragmentShader = shader.fragmentShader
        .replace(
          '#include <common>',
          '#include <common>\nvarying vec3 vBallSurface;',
        )
        .replace(
          '#include <map_fragment>',
          /* glsl */ `#include <map_fragment>
          vec3 leatherDirection = normalize(vBallSurface);
          float latitude = acos(clamp(leatherDirection.y, -1.0, 1.0)) - 1.57079633;
          float twist = (leatherDirection.x * leatherDirection.x - leatherDirection.z * leatherDirection.z)
            / max(dot(leatherDirection.xz, leatherDirection.xz), 0.00001);
          float straightChannel = min(abs(leatherDirection.x), abs(leatherDirection.z));
          float curvedChannel = min(abs(latitude - 0.53 * twist), abs(latitude + 0.53 * twist));
          float channel = min(straightChannel, curvedChannel);
          float channelAA = max(fwidth(channel), 0.0001);
          float rubber = 1.0 - smoothstep(0.0083 - channelAA * 0.5, 0.0083 + channelAA * 0.5, channel);
          diffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.004, 0.003, 0.0025), rubber);
        `,
        );
    };
    const sphereGeometry = own(new THREE.SphereGeometry(0.12, 96, 64));
    const createBall = () => {
      const group = add(new THREE.Group());
      const body = add(new THREE.Mesh(sphereGeometry, ballSurface), group);
      body.castShadow = true;
      body.receiveShadow = true;
      return group;
    };
    idleBall = createBall();
    idleBall.position.set(2.6, 0.123, 4.1);
    idleBall.rotation.set(0.22, -0.38, 0.14);
    ball = createBall();
    ball.visible = false;
    // Its moving projection is decorative; the hardware shadow stays cached throughout a shot.
    ball.traverse((object) => {
      if (object instanceof THREE.Mesh) object.castShadow = false;
    });

    selection = createMarker('#FF5A1F', own);
    add(selection);
    selection.visible = false;
    madeMarker = createMarker('#65A2FF', own);
    add(madeMarker);
    madeMarker.visible = false;

    // Three evaluates the physical BRDF even when a local light contributes zero.
    // The macro ball lights have a short range, so most arena pixels can skip them.
    const guardedLighting = THREE.ShaderChunk.lights_fragment_begin.replaceAll(
      'RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight );',
      'if ( directLight.visible ) { RE_Direct( directLight, geometryPosition, geometryNormal, geometryViewDir, geometryClearcoatNormal, material, reflectedLight ); }',
    );
    const surfaces = new Set<THREE.Material>();
    scene.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      for (const surface of Array.isArray(object.material)
        ? object.material
        : [object.material]) {
        if (
          !(
            'isMeshStandardMaterial' in surface ||
            'isMeshPhongMaterial' in surface
          ) ||
          surfaces.has(surface)
        )
          continue;
        surfaces.add(surface);
        const compile = surface.onBeforeCompile;
        const cacheKey = surface.customProgramCacheKey.bind(surface);
        surface.onBeforeCompile = (
          shader: Parameters<THREE.Material['onBeforeCompile']>[0],
          webgl: THREE.WebGLRenderer,
        ) => {
          compile.call(surface, shader, webgl);
          shader.fragmentShader = shader.fragmentShader.replace(
            '#include <lights_fragment_begin>',
            guardedLighting,
          );
        };
        surface.customProgramCacheKey = () =>
          `${cacheKey()}:visible-local-light-v1`;
      }
    });

    // Query the actual HDR/depth formats rather than assuming MAX_SAMPLES also applies to them.
    const colorSamples = Array.from(
      (gl.getInternalformatParameter(
        gl.RENDERBUFFER,
        gl.RGBA16F,
        gl.SAMPLES,
      ) as Int32Array | null) ?? new Int32Array(),
    );
    const depthSamples = Array.from(
      (gl.getInternalformatParameter(
        gl.RENDERBUFFER,
        gl.DEPTH_COMPONENT24,
        gl.SAMPLES,
      ) as Int32Array | null) ?? new Int32Array(),
    );
    supportedSamples = colorSamples.filter((value) =>
      depthSamples.includes(value),
    );
    composer = new EffectComposer(
      renderer,
      new THREE.WebGLRenderTarget(1, 1, {
        type: THREE.HalfFloatType,
        depthBuffer: false,
      }),
    );
    // Only geometry needs multisampling. Bloom and output use ordinary HDR buffers,
    // avoiding repeated multisample resolves for every fullscreen postprocessing pass.
    scenePass = own(
      new AntialiasedScenePass(
        scene,
        camera,
        new THREE.WebGLRenderTarget(1, 1, {
          type: THREE.HalfFloatType,
          resolveDepthBuffer: false,
        }),
      ),
    );
    composer.addPass(scenePass);
    bloom = own(
      new UnrealBloomPass(new THREE.Vector2(1024, 768), 0.28, 0.4, 1.1),
    );
    // Three r186's bloom dispose omits this material.
    own(bloom.materialHighPassFilter);
    composer.addPass(bloom);
    composer.addPass(own(new OutputPass()));
    fallbackAA = own(new ShaderPass(FXAAShader));
    composer.addPass(fallbackAA);
    resize();
    // Compile upfront before main reveals the canvas; no frame-blocking asset fetch.
    const previousTarget = renderer.getRenderTarget();
    renderer.setRenderTarget(scenePass.target);
    try {
      await renderer.compileAsync(scene, camera);
      if (nativeSamples > 0 && !disposed && !options.signal.aborted) {
        // Direct output has tone-mapping and color-space defines absent from HDR materials.
        // Compile that variant now, so an adaptive quality change cannot introduce a shader hitch.
        renderer.setRenderTarget(null);
        await renderer.compileAsync(scene, camera);
      }
    } finally {
      if (!disposed) renderer.setRenderTarget(previousTarget);
    }
    if (disposed || options.signal.aborted)
      throw new DOMException('Scene aborted', 'AbortError');
    // Viewport or display density may have changed while shader compilation was pending.
    resize();
    drawFrame();
    if (failed) throw new Error('Court shaders could not initialize');
    if (motionEnabled && !document.hidden) {
      // A prepared GPU draw leaves room for native composition and page animation.
      // Probe the same ordered tiers before revealing the scene, while the matching
      // poster remains visible. Compilation and network delays are not evidence.
      const calibration: { quality: SceneQuality; milliseconds: number }[] = [];
      for (const candidate of ['full', 'effects', 'density'] as const) {
        if (candidate !== quality) applyQuality(candidate);
        const milliseconds = await preparedDrawCost(
          gl,
          drawFrame,
          options.signal,
        );
        if (milliseconds === null) break;
        calibration.push({ quality: candidate, milliseconds });
        if (milliseconds <= 8) break;
      }
      canvas.dataset.calibration = JSON.stringify(calibration);
      monitor.quality = quality;
      monitor.reset();
    }
    if (disposed || failed || options.signal.aborted)
      throw new DOMException('Scene aborted', 'AbortError');
    ready = true;
    canvas.dataset.sceneReady = 'true';
    canvas.dataset.chapter = frame.chapter;
    canvas.dataset.storyProgress = frame.progress.toFixed(4);
    canvas.dataset.renderCount = '0';
    options.onQualityChange?.(quality);
    canvas.addEventListener('pointerup', onPointerUp);
    window.addEventListener('resize', resize, { passive: true });
    resizeObserver = new ResizeObserver(() => resize());
    resizeObserver.observe(canvas);
    monitorResolution();
    if (motionEnabled)
      introduction = gsap.to(intro, {
        progress: 1,
        duration: 1.8,
        ease: 'power3.out',
        onUpdate: requestRender,
        onComplete: requestRender,
      });
    requestRender();
  } catch (error) {
    dispose();
    throw error;
  }

  function removeTrail() {
    if (!trail) return;
    scene.remove(trail);
    trail.geometry.dispose();
    trail.material.dispose();
    trail = undefined;
  }

  function reset() {
    shotContinuation.cancel();
    flight = undefined;
    removeTrail();
    if (selection) selection.visible = false;
    if (madeMarker) madeMarker.visible = false;
    if (ball) ball.visible = false;
    hardware?.setNetImpact(0);
    if (renderer) renderer.shadowMap.needsUpdate = true;
    requestRender();
  }

  return {
    setStoryFrame(nextFrame) {
      if (disposed) return;
      const progress = Number.isFinite(nextFrame.progress)
        ? clamp(nextFrame.progress)
        : 0;
      if (
        frame.chapter === nextFrame.chapter &&
        frame.progress === progress &&
        frame.active === nextFrame.active
      )
        return;
      frame = { ...nextFrame, progress };
      canvas.dataset.chapter = frame.chapter;
      canvas.dataset.storyProgress = progress.toFixed(4);
      if (frame.chapter !== 'hero' || frame.progress > 0.001) {
        introduction?.kill();
        intro.progress = 1;
      }
      changingUntil = performance.now() + 160;
      if (!frame.active || frame.chapter === 'download') {
        cancelAnimationFrame(animationFrame);
        animationFrame = 0;
        monitor.reset();
        canvas.dataset.rendering = 'off';
        return;
      }
      updateCamera();
      requestRender();
    },
    exportFrame() {
      if (disposed || !renderer || !composer)
        throw new Error('Court scene is unavailable');
      updateCamera();
      drawFrame();
      return canvas.toDataURL('image/webp', 0.9);
    },
    selectPoint(point) {
      if (disposed || !selection) return;
      selection.visible = point !== null;
      if (point) selection.position.copy(worldPoint(point));
      requestRender();
    },
    setMadePoint(point) {
      if (disposed) return;
      if (!shotContinuation.restore(point)) reset();
      if (!madeMarker || !point) return;
      madeMarker.position.copy(worldPoint(point));
      madeMarker.scale.set(1, 1, 1);
      madeMarker.visible = true;
      requestRender();
    },
    shoot(point) {
      if (disposed || !ball || !madeMarker || !selection) return;
      reset();
      if (!motionEnabled) {
        madeMarker.position.copy(worldPoint(point));
        madeMarker.visible = true;
        requestRender();
        return;
      }
      const launch = worldPoint(point);
      launch.y = 1.2;
      const apex = launch.clone().lerp(RIM, 0.5);
      apex.y = Math.max(5.2, 4.4 + launch.distanceTo(RIM) * 0.12);
      const arc = new THREE.QuadraticBezierCurve3(launch, apex, RIM);
      const trailSurface = new THREE.ShaderMaterial({
        uniforms: { uHead: { value: 0 }, uOpacity: { value: 0.86 } },
        vertexShader: trailVertex,
        fragmentShader: trailFragment,
        transparent: true,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      });
      trail = add(
        new THREE.Mesh(
          new THREE.TubeGeometry(arc, 64, 0.035, 8, false),
          trailSurface,
        ),
      );
      trail.visible = quality === 'full';
      const flyingBall = ball;
      const marker = madeMarker;
      const flightTrail = trail;
      flyingBall.position.copy(launch);
      flyingBall.visible = true;
      const motion = { progress: 0, fall: 0, rebound: 0 };
      flight = gsap.timeline();
      const currentFlight = flight;
      const shotGeneration = shotContinuation.begin(point, () => {
        currentFlight.kill();
        if (flight === currentFlight) flight = undefined;
      });
      flight
        .to(motion, {
          progress: 1,
          duration: 1.2,
          ease: 'none',
          onUpdate() {
            if (disposed || !shotContinuation.isCurrent(shotGeneration)) return;
            arc.getPoint(motion.progress, flyingBall.position);
            flyingBall.rotation.set(
              motion.progress * Math.PI * 3.4,
              motion.progress * Math.PI * 1.8,
              0.15,
            );
            flightTrail.material.uniforms.uHead!.value = motion.progress;
            requestRender();
          },
        })
        .to(motion, {
          fall: 1,
          duration: 0.35,
          ease: 'power2.in',
          onUpdate() {
            if (disposed || !shotContinuation.isCurrent(shotGeneration)) return;
            flyingBall.position.y = RIM.y - motion.fall * 0.95;
            hardware?.setNetImpact(Math.sin(motion.fall * Math.PI));
            flightTrail.material.uniforms.uOpacity!.value =
              (1 - motion.fall) * 0.86;
            requestRender();
          },
          onComplete() {
            if (disposed || !shotContinuation.isCurrent(shotGeneration)) return;
            flyingBall.visible = false;
            hardware?.setNetImpact(0);
            if (renderer) renderer.shadowMap.needsUpdate = true;
            marker.position.copy(worldPoint(point));
            marker.scale.set(1, 1, 1);
            marker.visible = true;
            removeTrail();
            requestRender();
          },
        })
        .to(motion, {
          rebound: 1,
          duration: 0.58,
          ease: 'none',
          onUpdate() {
            if (disposed || !shotContinuation.isCurrent(shotGeneration)) return;
            hardware?.setNetImpact(
              Math.sin(motion.rebound * Math.PI * 3) *
                Math.exp(-motion.rebound * 4) *
                0.3,
            );
            requestRender();
          },
          onComplete() {
            if (disposed || !shotContinuation.isCurrent(shotGeneration)) return;
            hardware?.setNetImpact(0);
            shotContinuation.complete(shotGeneration);
            flight = undefined;
            requestRender();
          },
        });
      if (paused) flight.pause();
      requestRender();
    },
    reset,
    setMotionEnabled(enabled) {
      if (disposed || motionEnabled === enabled) return;
      motionEnabled = enabled;
      monitor.reset();
      if (!enabled) {
        introduction?.kill();
        intro.progress = 1;
        shotContinuation.cancel();
        flight = undefined;
        removeTrail();
        if (ball) ball.visible = false;
        hardware?.setNetImpact(0);
        if (renderer) renderer.shadowMap.needsUpdate = true;
        selection?.scale.set(1, 1, 1);
      }
      requestRender();
    },
    setPaused(nextPaused) {
      if (disposed || paused === nextPaused) return;
      paused = nextPaused;
      if (paused) {
        cancelAnimationFrame(animationFrame);
        animationFrame = 0;
        flight?.pause();
        introduction?.pause();
        monitor.reset();
        canvas.dataset.rendering = 'paused';
      } else {
        monitor.reset();
        flight?.resume();
        introduction?.resume();
        requestRender();
      }
    },
    dispose() {
      removeTrail();
      dispose();
    },
  };
}

/** Resolve scene edges once, then keep all postprocessing buffers single-sampled. */
class AntialiasedScenePass extends RenderPass {
  private readonly copy = new ShaderPass(CopyShader);

  constructor(
    scene: THREE.Scene,
    camera: THREE.Camera,
    readonly target: THREE.WebGLRenderTarget,
  ) {
    super(scene, camera);
  }

  override setSize(width: number, height: number) {
    this.target.setSize(width, height);
  }

  override render(
    renderer: THREE.WebGLRenderer,
    writeBuffer: THREE.WebGLRenderTarget,
    readBuffer: THREE.WebGLRenderTarget,
    deltaTime: number,
    maskActive: boolean,
  ) {
    const toScreen = this.renderToScreen;
    this.renderToScreen = false;
    super.render(renderer, writeBuffer, this.target, deltaTime, maskActive);
    this.renderToScreen = toScreen;
    this.copy.renderToScreen = toScreen;
    this.copy.render(renderer, readBuffer, this.target, deltaTime, maskActive);
  }

  override dispose() {
    this.target.dispose();
    this.copy.dispose();
  }
}

function makeLeatherTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 256;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('Ball texture could not initialize');
  context.fillStyle = '#C27436';
  context.fillRect(0, 0, 512, 256);
  // Fixed seed keeps generated leather identical across reloads and screenshots.
  let seed = 7169;
  const random = () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    return seed / 4294967296;
  };
  for (let dot = 0; dot < 11500; dot += 1) {
    context.fillStyle = dot % 2 ? 'rgba(60,26,8,.19)' : 'rgba(251,196,123,.26)';
    context.beginPath();
    context.arc(
      random() * 512,
      random() * 256,
      0.4 + random() * 0.65,
      0,
      Math.PI * 2,
    );
    context.fill();
  }
  return new THREE.CanvasTexture(canvas);
}

function createMarker(
  color: string,
  own: <T extends { dispose(): void }>(resource: T) => T,
) {
  const group = new THREE.Group();
  const surface = own(
    new THREE.MeshBasicMaterial({
      color,
      transparent: true,
      opacity: 0.95,
      depthWrite: false,
      toneMapped: true,
    }),
  );
  const ring = new THREE.Mesh(
    own(new THREE.RingGeometry(0.32, 0.36, 48)),
    surface,
  );
  ring.rotation.x = -Math.PI / 2;
  group.add(ring);
  const dot = new THREE.Mesh(own(new THREE.CircleGeometry(0.06, 20)), surface);
  dot.rotation.x = -Math.PI / 2;
  dot.position.y = 0.002;
  group.add(dot);
  for (let index = 0; index < 4; index += 1) {
    const tick = new THREE.Mesh(
      own(new THREE.BoxGeometry(0.05, 0.012, 0.16)),
      surface,
    );
    const angle = (index * Math.PI) / 2;
    tick.position.set(Math.sin(angle) * 0.47, 0.004, Math.cos(angle) * 0.47);
    tick.rotation.y = angle;
    group.add(tick);
  }
  return group;
}
