import { forwardRef, useState } from 'react';
import { formatMoneyInput, parseMoneyInput } from '@/utils/money-input';

export const MoneyInput = forwardRef(function MoneyInput(
  { value, defaultValue = '', onChange, name, onBlur, ...props },
  ref,
) {
  const [draft, setDraft] = useState(String(defaultValue ?? ''));
  const raw = value === undefined ? draft : String(value ?? '');
  return (
    <>
      {name && <input type="hidden" name={name} value={raw} />}
      <input
        {...props}
        ref={ref}
        type="text"
        inputMode="decimal"
        value={formatMoneyInput(raw)}
        onBlur={onBlur}
        onChange={(event) => {
          const next = parseMoneyInput(event.target.value);
          if (next === null) return;
          const input = event.target;
          const chars = input.value.slice(0, input.selectionStart).replaceAll('.', '').length;
          setDraft(next);
          onChange?.(next);
          requestAnimationFrame(() => {
            let position = 0,
              count = 0;
            const formatted = formatMoneyInput(next);
            while (position < formatted.length && count < chars) {
              if (formatted[position] !== '.') count++;
              position++;
            }
            if (document.activeElement === input) input.setSelectionRange(position, position);
          });
        }}
      />
    </>
  );
});
MoneyInput.displayName = 'MoneyInput';
