import { useId, useState } from 'react';
import { CalendarDays } from 'lucide-react';

function MonthFilter({ value, onChange }) {
  const id = useId();
  const [text, setText] = useState(() => (value ? value.split('-').reverse().join('/') : ''));
  const changeText = (event) => {
    const next = event.target.value.replace(/[^0-9/]/g, '').slice(0, 7);
    setText(next);
    const match = /^(0[1-9]|1[0-2])\/(\d{4})$/.exec(next);
    onChange(match ? `${match[2]}-${match[1]}` : '');
  };
  return (
    <div className="report-month-field">
      <label htmlFor={id}>Tháng</label>
      <div className="report-month-input">
        <input
          id={id}
          type="text"
          inputMode="numeric"
          placeholder="MM/YYYY"
          maxLength={7}
          value={text}
          onChange={changeText}
          autoComplete="off"
        />
        <span className="report-month-calendar">
          <CalendarDays size={18} aria-hidden="true" />
          <input
            type="month"
            aria-label="Chọn tháng từ lịch"
            min="1900-01"
            max="9998-12"
            value={value}
            onChange={(event) => {
              const next = event.target.value;
              setText(next ? next.split('-').reverse().join('/') : '');
              onChange(next);
            }}
          />
        </span>
      </div>
    </div>
  );
}

export default function ReportPeriodFilter({ value, onChange, label = 'Lọc thời gian báo cáo' }) {
  const update = (key, next) => onChange({ ...value, [key]: next });
  return (
    <div className="report-period-filter" role="group" aria-label={label}>
      <label>
        Lọc theo
        <select
          aria-label="Lọc theo"
          value={value.type}
          onChange={(e) => update('type', e.target.value)}
        >
          <option value="all">Toàn bộ</option>
          <option value="day">Ngày</option>
          <option value="month">Tháng</option>
          <option value="quarter">Quý</option>
          <option value="year">Năm</option>
        </select>
      </label>
      {value.type === 'day' && (
        <label>
          Ngày
          <input
            type="date"
            min="1900-01-01"
            max="9998-12-31"
            value={value.day}
            onChange={(e) => update('day', e.target.value)}
          />
        </label>
      )}
      {value.type === 'month' && (
        <MonthFilter value={value.month} onChange={(month) => update('month', month)} />
      )}
      {value.type === 'quarter' && (
        <label>
          Quý
          <select
            aria-label="Quý"
            value={value.quarter}
            onChange={(e) => update('quarter', e.target.value)}
          >
            {[1, 2, 3, 4].map((q) => (
              <option key={q} value={q}>
                Quý {q}
              </option>
            ))}
          </select>
        </label>
      )}
      {['quarter', 'year'].includes(value.type) && (
        <label>
          Năm
          <input
            type="number"
            min="1900"
            max="9998"
            step="1"
            value={value.year}
            onChange={(e) => update('year', e.target.value)}
          />
        </label>
      )}
    </div>
  );
}
