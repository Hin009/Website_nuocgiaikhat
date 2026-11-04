export function formatMoneyInput(value) {
  if (value == null || value === '') return '';
  const [whole, fraction] = String(value).split('.');
  const integer = (whole || '0').replace(/^0+(?=\d)/, '');
  if (!/^\d+$/.test(integer)) return '';
  return (
    integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.') +
    (fraction === undefined ? '' : ',' + fraction.slice(0, 2))
  );
}

// Vietnamese display: dots group thousands; comma separates fractional đồng.
export function parseMoneyInput(display) {
  if (display === '') return '';
  if (!/^[0-9.]+(?:,[0-9]{0,2})?$/.test(display)) return null;
  const raw = display.replaceAll('.', '').replace(',', '.');
  if (!/^\d+(?:\.\d{0,2})?$/.test(raw)) return null;
  return raw.replace(/^0+(?=\d)/, '');
}
