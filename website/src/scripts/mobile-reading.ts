/** Static content bounds exclude viewport-filling wrappers and animated poses. */
export function mobileContentBottom(section: HTMLElement) {
  let bottom = 0;
  for (const item of section.querySelectorAll<HTMLElement>(
    'h1, h2, h3, p, li, a, button, summary, img, [data-glass-card], [data-demo-court-host]',
  )) {
    const closed = item.closest<HTMLDetailsElement>('details:not([open])');
    if (closed && !closed.querySelector('summary')?.contains(item)) continue;
    if (
      !item.getClientRects().length ||
      getComputedStyle(item).display === 'contents'
    )
      continue;
    let top = 0;
    for (
      let node: HTMLElement | null = item;
      node;
      node = node.offsetParent as HTMLElement | null
    )
      top += node.offsetTop;
    bottom = Math.max(bottom, top + item.offsetHeight);
  }
  return bottom;
}
