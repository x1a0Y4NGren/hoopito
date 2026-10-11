import * as THREE from 'three';
import { gsap } from 'gsap';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { FXAAShader } from 'three/addons/shaders/FXAAShader.js';
import { CopyShader } from 'three/addons/shaders/CopyShader.js';
import { Reflector } from 'three/addons/objects/Reflector.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { createCourtHardware } from './court-hardware';
import { loadCourtTextures } from './court-textures';
import type {
  CourtPoint,
  CourtScene,
  CourtSceneOptions,
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
  scene.background = new THREE.Color('#101112');
  scene.fog = new THREE.FogExp2('#101112', 0.028);
  const camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100);
  const disposables = new Set<{ dispose(): void }>();
  let renderer: THREE.WebGLRenderer | undefined;
  let composer: EffectComposer | undefined;
  let animationFrame = 0;
  let disposed = false;
  let paused = false;
  let failed = false;
  let ready = false;
  let motionEnabled = options.motionEnabled;
  let quality: 'high' | 'low' = 'high';
  let journey = 0;
  let flight: gsap.core.Timeline | undefined;
  let introduction: gsap.core.Tween | undefined;
  let trail: THREE.Mesh<THREE.TubeGeometry, THREE.ShaderMaterial> | undefined;
  let previousFrame = 0;
  let sampleStart = 0;
  let sampleCount = 0;
  let sampleTotal = 0;
  let slowWindows = 0;
  let pendingLowQuality = false;
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
  const tube = (
    points: THREE.Vector3[],
    radius: number,
    surface: THREE.Material,
    parent: THREE.Object3D = scene,
    closed = false,
  ) => {
    const curve = new THREE.CatmullRomCurve3(points, closed);
    const mesh = add(
      new THREE.Mesh(
        own(
          new THREE.TubeGeometry(
            curve,
            Math.max(12, points.length * 2),
            radius,
            5,
            closed,
          ),
        ),
        surface,
      ),
      parent,
    );
    mesh.castShadow = true;
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
    flight?.kill();
    removeTrail();
    canvas.removeEventListener('pointerup', onPointerUp);
    canvas.removeEventListener('webglcontextlost', onContextLost);
    window.removeEventListener('resize', resize);
    resolutionQuery?.removeEventListener('change', onResolutionChange);
    options.signal.removeEventListener('abort', onAbort);
    for (const resource of disposables) resource.dispose();
    disposables.clear();
    composer?.dispose();
    renderer?.dispose();
    scene.clear();
    delete canvas.dataset.sceneReady;
  }

  // Declared before setup so cancellation also works during shader compilation.
  let reflection: Reflector | undefined;
  let bloom: UnrealBloomPass | undefined;
  let fallbackAA: ShaderPass | undefined;
  let scenePass: AntialiasedScenePass | undefined;
  let supportedSamples: number[] = [];
  let resolutionQuery: MediaQueryList | undefined;
  let paint: THREE.ShaderMaterial | undefined;
  let selection: THREE.Group | undefined;
  let madeMarker: THREE.Group | undefined;
  let ball: THREE.Group | undefined;
  let idleBall: THREE.Group | undefined;
  let keyLight: THREE.SpotLight | undefined;
  let hardware: ReturnType<typeof createCourtHardware> | undefined;
  let positions: THREE.CatmullRomCurve3 | undefined;
  let targets: THREE.CatmullRomCurve3 | undefined;
  const desiredCamera = new THREE.Vector3();
  const desiredTarget = new THREE.Vector3();
  const nearCamera = new THREE.Vector3(3.65, 0.42, 2.85);
  const nearTarget = new THREE.Vector3(2.96, 0.14, 1.9);

  function requestRender() {
    if (!disposed && !paused && ready && !animationFrame)
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
    // Reduce optional effects under load, preserving the court's native pixel density.
    const desiredRatio = Math.min(2, window.devicePixelRatio || 1);
    // Bound allocation on very large displays; retain native pixels at ordinary desktop sizes.
    const pixelRatio = Math.min(
      desiredRatio,
      Math.max(1, Math.sqrt(6_000_000 / (width * height))),
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
    canvas.dataset.antialias = samples ? `msaa-${samples}` : 'fxaa';
    renderer.setPixelRatio(pixelRatio);
    renderer.setSize(width, height, false);
    composer.setPixelRatio(renderer.getPixelRatio());
    composer.setSize(width, height);
    // Bloom is deliberately soft; its blur buffers need not match the sharp scene's Retina resolution.
    const bloomScale = Math.min(1, 1280 / (width * pixelRatio));
    bloom?.setSize(
      width * pixelRatio * bloomScale,
      height * pixelRatio * bloomScale,
    );
    fallbackAA?.uniforms.resolution.value.set(
      1 / (width * pixelRatio),
      1 / (height * pixelRatio),
    );
    canvas.dataset.pixelRatio = pixelRatio.toFixed(2);
    previousFrame = 0;
    sampleStart = 0;
    sampleCount = 0;
    sampleTotal = 0;
    updateCamera();
    requestRender();
  }

  function updateCamera() {
    if (!positions || !targets) return;
    positions.getPoint(journey, desiredCamera);
    targets.getPoint(journey, desiredTarget);
    if (journey < 0.01 && intro.progress < 1) {
      desiredCamera.lerpVectors(nearCamera, desiredCamera, intro.progress);
      desiredTarget.lerpVectors(nearTarget, desiredTarget, intro.progress);
    }
    camera.position.copy(desiredCamera);
    aim.copy(desiredTarget);
    camera.lookAt(aim);
    camera.updateMatrixWorld();
    if (paint)
      paint.uniforms.uReveal!.value = Math.min(
        1.1,
        intro.progress * 1.12 + journey,
      );
  }

  function onPointerUp(event: PointerEvent) {
    if (
      disposed ||
      paused ||
      event.button !== 0 ||
      journey < 0.36 ||
      journey > 0.67
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

  function lowerQuality() {
    if (quality === 'low' || disposed) return;
    quality = 'low';
    pendingLowQuality = false;
    if (reflection) reflection.visible = false;
    if (bloom) bloom.enabled = false;
    if (renderer) renderer.shadowMap.enabled = false;
    // Invalidate Three's light-state shader variant as well as its shadow render.
    if (keyLight) keyLight.castShadow = false;
    canvas.dataset.quality = quality;
    options.onQualityChange?.(quality);
    slowWindows = 0;
    resize();
  }

  function render(now: number) {
    animationFrame = 0;
    if (disposed || paused || !ready || !renderer || !composer) return;
    try {
      updateCamera();
      if (idleBall && motionEnabled) {
        idleBall.rotation.y = now * 0.00012;
        idleBall.rotation.z = 0.18 + Math.sin(now * 0.0002) * 0.035;
      }
      if (selection?.visible && motionEnabled) {
        const pulse = 1 + Math.sin(now * 0.003) * 0.025;
        selection.scale.set(pulse, 1, pulse);
      }
      composer.render();
    } catch {
      fail('initialization');
      return;
    }

    // Accessibility uses on-demand frames, whose gaps are not performance samples.
    if (!motionEnabled) return;
    // Windowed measurements exclude background gaps, startup and resize samples.
    if (previousFrame) {
      sampleTotal += now - previousFrame;
      sampleCount += 1;
    }
    previousFrame = now;
    if (!sampleStart) sampleStart = now;
    if (now - sampleStart > 2500 && sampleCount > 3) {
      const frameMs = sampleTotal / sampleCount;
      canvas.dataset.frameMs = frameMs.toFixed(2);
      canvas.dataset.fps = (1000 / frameMs).toFixed(1);
      slowWindows =
        frameMs > (quality === 'high' ? 32 : 45) ? slowWindows + 1 : 0;
      if (quality === 'high' && slowWindows >= 2) pendingLowQuality = true;
      if (quality === 'low' && slowWindows >= 3) {
        fail('performance');
        return;
      }
      sampleStart = now;
      sampleCount = 0;
      sampleTotal = 0;
    }
    if (pendingLowQuality) lowerQuality();
    requestRender();
  }

  options.signal.addEventListener('abort', onAbort, { once: true });
  canvas.addEventListener('webglcontextlost', onContextLost, {
    passive: false,
  });

  try {
    renderer = new THREE.WebGLRenderer({
      canvas,
      // Geometry is antialiased offscreen; the final fullscreen quad needs no MSAA.
      antialias: false,
      alpha: false,
      powerPreference: 'high-performance',
    });
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.15;
    renderer.shadowMap.enabled = true;
    // Lights and court hardware are static. Rebuild their shadow only when the animated ball changes.
    renderer.shadowMap.autoUpdate = false;
    renderer.shadowMap.needsUpdate = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.setClearColor('#101112', 1);
    renderer.debug.onShaderError = () => fail('initialization');
    // Three r186 creates a WebGL2 context; the installed declarations also retain the legacy union.
    const gl = renderer.getContext() as WebGL2RenderingContext;
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
    scene.environmentIntensity = 0.28;
    room.dispose();
    pmrem.dispose();

    const emissiveAmber = material({
      color: AMBER,
      emissive: AMBER,
      emissiveIntensity: 4.3,
      toneMapped: false,
    });
    const blue = material({
      color: '#437AF4',
      emissive: '#437AF4',
      emissiveIntensity: 1.8,
    });
    const red = material({
      color: '#F06959',
      emissive: '#F06959',
      emissiveIntensity: 1.8,
    });

    add(new THREE.HemisphereLight('#C9D8E3', '#090807', 1.5));
    keyLight = add(new THREE.SpotLight('#FFEBD4', 850, 55, 0.54, 0.6, 1.6));
    keyLight.position.set(5, 15, 2);
    keyLight.target.position.set(0, 0, -1);
    add(keyLight.target);
    keyLight.castShadow = true;
    keyLight.shadow.mapSize.set(1024, 1024);
    keyLight.shadow.bias = -0.00035;
    keyLight.shadow.normalBias = 0.035;
    keyLight.shadow.camera.near = 2;
    keyLight.shadow.camera.far = 35;
    own(keyLight.shadow);
    const rimLight = add(
      new THREE.SpotLight('#FF6935', 420, 40, 0.68, 0.75, 1.6),
    );
    rimLight.position.set(-8, 8, -7);
    rimLight.target.position.set(0, 2, -3);
    add(rimLight.target);
    const coolLight = add(new THREE.PointLight('#7B9ED1', 75, 22, 1.8));
    coolLight.position.set(7, 4, 7);

    // A lit room without a visible box: rails and light banks define its scale.
    box(
      [17, 0.18, 16],
      [0, -0.14, 0],
      material({ color: '#15191A', roughness: 0.75 }),
    );
    box([17.05, 0.026, 0.035], [0, -0.024, -8], emissiveAmber);
    box([0.035, 0.026, 16], [8.5, -0.024, 0], emissiveAmber);
    box([0.035, 0.026, 16], [-8.5, -0.024, 0], emissiveAmber);
    box([17.05, 0.026, 0.035], [0, -0.024, 8], emissiveAmber);

    reflection = add(
      new Reflector(own(new THREE.PlaneGeometry(WIDTH, LENGTH)), {
        color: '#15191A',
        textureWidth: 512,
        textureHeight: 512,
        clipBias: 0.003,
        // The reflection is softly filtered beneath the wood, so it needs no MSAA.
        multisample: 0,
      }),
    );
    reflection.rotation.x = -Math.PI / 2;
    reflection.position.y = -0.002;
    own(reflection);

    const woodTexture = textures.maple;
    // The source tile depicts roughly a two-metre patch, rather than oversized striped boards.
    woodTexture.repeat.set(WIDTH / 2, LENGTH / 2);
    const woodHeight = own(woodTexture.clone());
    woodHeight.colorSpace = THREE.NoColorSpace;
    const wood = own(
      new THREE.MeshStandardMaterial({
        color: '#AE9F85',
        map: woodTexture,
        bumpMap: woodHeight,
        bumpScale: 0.002,
        roughness: 0.34,
        metalness: 0.025,
        transparent: true,
        opacity: 0.91,
        depthWrite: false,
      }),
    );
    const floor = add(
      new THREE.Mesh(own(new THREE.PlaneGeometry(WIDTH, LENGTH)), wood),
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = 0.004;
    floor.receiveShadow = true;
    paint = own(
      new THREE.ShaderMaterial({
        uniforms: { uReveal: { value: 0 } },
        vertexShader: courtVertex,
        fragmentShader: courtFragment,
        transparent: true,
        depthWrite: false,
        polygonOffset: true,
        polygonOffsetFactor: -1,
        toneMapped: false,
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
        material({
          color: '#142332',
          roughness: 0.4,
          transparent: true,
          opacity: 0.38,
          depthWrite: false,
        }),
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

    const leather = own(makeLeatherTexture());
    leather.colorSpace = THREE.SRGBColorSpace;
    const ballSurface = material({
      color: '#E97D2D',
      map: leather,
      bumpMap: leather,
      bumpScale: 0.009,
      roughness: 0.77,
      metalness: 0.015,
    });
    const seamSurface = material({ color: '#101112', roughness: 0.82 });
    const sphereGeometry = own(new THREE.SphereGeometry(0.12, 40, 28));
    const seamGeometry = own(new THREE.TorusGeometry(0.1205, 0.0023, 5, 100));
    const createBall = () => {
      const group = add(new THREE.Group());
      const body = add(new THREE.Mesh(sphereGeometry, ballSurface), group);
      body.castShadow = true;
      body.receiveShadow = true;
      for (let index = 0; index < 3; index += 1) {
        const seam = add(new THREE.Mesh(seamGeometry, seamSurface), group);
        if (index === 1) seam.rotation.y = Math.PI / 2;
        if (index === 2) seam.rotation.x = Math.PI / 2;
      }
      for (const sign of [-1, 1]) {
        const points: THREE.Vector3[] = [];
        for (let index = 0; index <= 64; index += 1) {
          const angle = (index / 64) * Math.PI * 2;
          const theta = Math.PI / 2 + sign * 0.53 * Math.cos(angle * 2);
          points.push(
            new THREE.Vector3(
              Math.sin(theta) * Math.cos(angle),
              Math.cos(theta),
              Math.sin(theta) * Math.sin(angle),
            ).multiplyScalar(0.1206),
          );
        }
        tube(points, 0.0021, seamSurface, group);
      }
      return group;
    };
    idleBall = createBall();
    idleBall.position.set(3.1, 0.125, 1.9);
    ball = createBall();
    ball.visible = false;

    selection = createMarker('#FF5A1F', own);
    add(selection);
    selection.visible = false;
    madeMarker = createMarker('#65A2FF', own);
    add(madeMarker);
    madeMarker.visible = false;

    // Look targets deliberately leave the hero's left third clear for type.
    positions = new THREE.CatmullRomCurve3(
      [
        new THREE.Vector3(15, 15, 25),
        new THREE.Vector3(11.5, 8.7, 12.5),
        new THREE.Vector3(-8.8, 31, 14),
        new THREE.Vector3(-5.5, 20, 9.7),
        new THREE.Vector3(13.5, 11.8, 22),
      ],
      false,
      'catmullrom',
      0.28,
    );
    targets = new THREE.CatmullRomCurve3(
      [
        new THREE.Vector3(-7, 0.1, -1),
        new THREE.Vector3(-2.8, 1, -2.6),
        new THREE.Vector3(-8.8, 0, 0),
        new THREE.Vector3(-2, 0.2, -0.1),
        new THREE.Vector3(-4.2, 0.2, -1),
      ],
      false,
      'catmullrom',
      0.28,
    );

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
    } finally {
      if (!disposed) renderer.setRenderTarget(previousTarget);
    }
    if (disposed || options.signal.aborted)
      throw new DOMException('Scene aborted', 'AbortError');
    // Viewport or display density may have changed while shader compilation was pending.
    resize();
    composer.render();
    if (failed) throw new Error('Court shaders could not initialize');
    ready = true;
    canvas.dataset.sceneReady = 'true';
    options.onQualityChange?.(quality);
    canvas.addEventListener('pointerup', onPointerUp);
    window.addEventListener('resize', resize, { passive: true });
    monitorResolution();
    if (motionEnabled)
      introduction = gsap.to(intro, {
        progress: 1,
        duration: 2.2,
        ease: 'power2.out',
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
    flight?.kill();
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
    setJourney(progress) {
      if (disposed) return;
      const next = motionEnabled
        ? clamp(progress)
        : Math.round(clamp(progress) * 4) / 4;
      if (journey === next) return;
      journey = next;
      if (journey >= 0.01 && intro.progress < 1) {
        introduction?.kill();
        intro.progress = 1;
      }
      updateCamera();
      requestRender();
    },
    selectPoint(point) {
      if (disposed || !selection) return;
      selection.visible = point !== null;
      if (point) selection.position.copy(worldPoint(point));
      requestRender();
    },
    setMadePoint(point) {
      if (disposed) return;
      reset();
      if (!madeMarker || !point) return;
      madeMarker.position.copy(worldPoint(point));
      madeMarker.scale.set(1, 1, 1);
      madeMarker.visible = true;
    },
    shoot(point) {
      if (disposed || !ball || !madeMarker || !selection) return;
      reset();
      if (!motionEnabled) {
        madeMarker.position.copy(worldPoint(point));
        madeMarker.visible = true;
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
      const flyingBall = ball;
      const marker = madeMarker;
      const flightTrail = trail;
      flyingBall.position.copy(launch);
      flyingBall.visible = true;
      const motion = { progress: 0, fall: 0 };
      flight = gsap.timeline();
      flight
        .to(motion, {
          progress: 1,
          duration: 1.2,
          ease: 'none',
          onUpdate() {
            if (disposed) return;
            arc.getPoint(motion.progress, flyingBall.position);
            if (renderer) renderer.shadowMap.needsUpdate = true;
            flyingBall.rotation.set(
              motion.progress * Math.PI * 3.4,
              motion.progress * Math.PI * 1.8,
              0.15,
            );
            flightTrail.material.uniforms.uHead!.value = motion.progress;
          },
        })
        .to(motion, {
          fall: 1,
          duration: 0.35,
          ease: 'power2.in',
          onUpdate() {
            flyingBall.position.y = RIM.y - motion.fall * 0.95;
            hardware?.setNetImpact(Math.sin(motion.fall * Math.PI));
            if (renderer) renderer.shadowMap.needsUpdate = true;
            flightTrail.material.uniforms.uOpacity!.value =
              (1 - motion.fall) * 0.86;
          },
          onComplete() {
            flyingBall.visible = false;
            hardware?.setNetImpact(0);
            if (renderer) renderer.shadowMap.needsUpdate = true;
            marker.position.copy(worldPoint(point));
            marker.scale.set(1, 1, 1);
            marker.visible = true;
            removeTrail();
          },
        });
      if (paused) flight.pause();
    },
    reset,
    setMotionEnabled(enabled) {
      if (disposed || motionEnabled === enabled) return;
      motionEnabled = enabled;
      previousFrame = 0;
      sampleStart = 0;
      sampleCount = 0;
      sampleTotal = 0;
      slowWindows = 0;
      if (!enabled) {
        introduction?.kill();
        intro.progress = 1;
        flight?.kill();
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
      } else {
        previousFrame = 0;
        sampleStart = 0;
        sampleCount = 0;
        sampleTotal = 0;
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
      toneMapped: false,
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
