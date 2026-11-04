import { Link } from 'react-router-dom';
import { useState, useId, Children, cloneElement, isValidElement } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  AlertCircle,
  PackageOpen,
  ChevronRight,
  Minus,
  Plus,
  LoaderCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { statusLabels } from '@/utils/format';
export function PageHeading({ eyebrow, title, description, action, headingLevel: Heading = 'h1' }) {
  return (
    <div className="page-heading">
      <div>
        {eyebrow && <span className="eyebrow">{eyebrow}</span>}
        <Heading>{title}</Heading>
        {description && <p>{description}</p>}
      </div>
      {action}
    </div>
  );
}
export function Breadcrumb({ items = [] }) {
  return (
    <nav aria-label="Đường dẫn" className="breadcrumb">
      <Link to="/">Trang chủ</Link>
      {items.map((item, i) => (
        <span key={i}>
          <ChevronRight size={13} />
          {item.to ? (
            <Link to={item.to}>{item.label}</Link>
          ) : (
            <span aria-current="page">{item.label}</span>
          )}
        </span>
      ))}
    </nav>
  );
}
export function EmptyState({
  title = 'Chưa có dữ liệu',
  description = 'Dữ liệu sẽ xuất hiện tại đây khi có cập nhật.',
  action,
  icon: Icon = PackageOpen,
}) {
  return (
    <div className="empty-state">
      <div className="empty-icon">
        <Icon size={32} strokeWidth={1.3} />
      </div>
      <h3>{title}</h3>
      <p>{description}</p>
      {action}
    </div>
  );
}
export function ErrorState({ error, retry }) {
  return (
    <div className="error-state" role="alert">
      <AlertCircle />
      <div>
        <h3>Không thể tải dữ liệu</h3>
        <p>{error?.message || 'Đã có lỗi xảy ra.'}</p>
      </div>
      {retry && (
        <Button variant="outline" onClick={retry}>
          Thử lại
        </Button>
      )}
    </div>
  );
}
export function Loading({ cards = false }) {
  return cards ? (
    <div className="product-grid">
      {Array.from({ length: 4 }, (_, i) => (
        <div key={i} className="skeleton-card">
          <div className="skeleton skeleton-image" />
          <div className="skeleton skeleton-line" />
          <div className="skeleton skeleton-line short" />
        </div>
      ))}
    </div>
  ) : (
    <div className="loading" role="status">
      <LoaderCircle className="spin" size={25} />
      <span>Đang tải dữ liệu…</span>
    </div>
  );
}
export function QueryState({ query, children, cards = false }) {
  if (query.isPending) return <Loading cards={cards} />;
  if (query.isError) return <ErrorState error={query.error} retry={query.refetch} />;
  return children;
}
export function Field({ label, error, children, className = '' }) {
  const id = useId();
  const decorate = (child) => {
    if (!isValidElement(child)) return child;
    if (['input', 'textarea', 'select'].includes(child.type) || child.props['data-field-control'])
      return cloneElement(child, {
        id: id + '-control',
        'aria-labelledby': id + '-label',
        'aria-invalid': !!error,
        'aria-describedby': error ? id + '-error' : undefined,
      });
    return child.props.children
      ? cloneElement(child, {}, Children.map(child.props.children, decorate))
      : child;
  };
  return (
    <div className={'field ' + className}>
      <label id={id + '-label'} htmlFor={id + '-control'}>
        {label}
      </label>
      {Children.map(children, decorate)}
      {error && (
        <small id={id + '-error'} role="alert">
          {error.message || error}
        </small>
      )}
    </div>
  );
}
export function StatusBadge({ status }) {
  return (
    <span className={'status-badge status-' + status?.toLowerCase()}>
      <i />
      {statusLabels[status] || status}
    </span>
  );
}
export function Quantity({ value, max, onChange }) {
  const [draft, setDraft] = useState(null);
  const valid = (v) => Number.isSafeInteger(Number(v)) && Number(v) >= 1 && Number(v) <= max;
  return (
    <div className="quantity">
      <button
        type="button"
        aria-label="Giảm số lượng"
        disabled={value <= 1}
        onClick={() => {
          setDraft(null);
          onChange(value - 1);
        }}
      >
        <Minus size={14} />
      </button>
      <input
        type="number"
        inputMode="numeric"
        aria-label="Số lượng"
        min="1"
        max={max}
        step="1"
        disabled={max < 1}
        value={draft ?? value}
        aria-invalid={draft !== null && !valid(draft)}
        onChange={(e) => {
          setDraft(e.target.value);
          if (valid(e.target.value)) onChange(Number(e.target.value));
        }}
        onBlur={() => {
          if (draft !== null && !valid(draft) && max >= 1)
            onChange(Math.min(max, Math.max(1, Math.trunc(Number(draft)) || 1)));
          setDraft(null);
        }}
      />
      <button
        type="button"
        aria-label="Tăng số lượng"
        disabled={value >= max}
        onClick={() => {
          setDraft(null);
          onChange(value + 1);
        }}
      >
        <Plus size={14} />
      </button>
    </div>
  );
}
export function Pagination({ page, pages, onChange }) {
  if (pages <= 1) return null;
  return (
    <nav aria-label="Phân trang" className="pagination">
      <Button
        size="icon"
        variant="outline"
        aria-label="Trang trước"
        disabled={page === 1}
        onClick={() => onChange(page - 1)}
      >
        <ArrowLeft size={16} />
      </Button>
      {Array.from({ length: pages }, (_, i) => (
        <button
          key={i}
          className={page === i + 1 ? 'active' : ''}
          aria-current={page === i + 1 ? 'page' : undefined}
          onClick={() => onChange(i + 1)}
        >
          {i + 1}
        </button>
      ))}
      <Button
        size="icon"
        variant="outline"
        aria-label="Trang sau"
        disabled={page === pages}
        onClick={() => onChange(page + 1)}
      >
        <ArrowRight size={16} />
      </Button>
    </nav>
  );
}
export function SectionHeading({ eyebrow, title, description, to, label = 'Xem tất cả' }) {
  return (
    <div className="section-heading">
      <div>
        {eyebrow && <span className="eyebrow">{eyebrow}</span>}
        <h2>{title}</h2>
        {description && <p>{description}</p>}
      </div>
      {to && (
        <Link className="text-link" to={to}>
          {label}
          <ArrowRight size={17} />
        </Link>
      )}
    </div>
  );
}
