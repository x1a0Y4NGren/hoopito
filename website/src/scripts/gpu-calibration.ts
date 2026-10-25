/** Measure prepared drawing only, excluding shader compilation and page loading. */
export async function preparedDrawCost(
  gl: WebGL2RenderingContext,
  draw: () => void,
  signal: AbortSignal,
): Promise<number | null> {
  const extension = gl.getExtension('EXT_disjoint_timer_query_webgl2');
  if (!extension) return null;
  const samples: number[] = [];
  for (let sample = 0; sample < 3; sample += 1) {
    if (signal.aborted) throw new DOMException('Scene aborted', 'AbortError');
    const query = gl.createQuery();
    if (!query) return null;
    try {
      gl.beginQuery(extension.TIME_ELAPSED_EXT, query);
      draw();
      gl.endQuery(extension.TIME_ELAPSED_EXT);
      gl.flush();
      const deadline = performance.now() + 240;
      while (!gl.getQueryParameter(query, gl.QUERY_RESULT_AVAILABLE)) {
        if (signal.aborted)
          throw new DOMException('Scene aborted', 'AbortError');
        if (performance.now() >= deadline || gl.isContextLost()) return null;
        await new Promise<void>((resolve) => setTimeout(resolve, 12));
      }
      if (gl.getParameter(extension.GPU_DISJOINT_EXT)) return null;
      const elapsed =
        Number(gl.getQueryParameter(query, gl.QUERY_RESULT)) / 1e6;
      if (!Number.isFinite(elapsed) || elapsed <= 0) return null;
      samples.push(elapsed);
    } finally {
      gl.deleteQuery(query);
    }
  }
  return samples.sort((a, b) => a - b)[1]!;
}
