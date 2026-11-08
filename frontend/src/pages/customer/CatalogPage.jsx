import { canPurchase } from '@/utils/inventory';
import { sortByExpiry } from '@/utils/expiry';
import { useSearchParams } from 'react-router-dom';
import { Search, SlidersHorizontal, X, ArrowUpRight } from 'lucide-react';
import { useState } from 'react';
import { useProducts, useCategories } from '@/hooks/useData';
import { Breadcrumb, QueryState, EmptyState, Pagination } from '@/components/common/Shared';
import { ProductCard } from '@/components/customer/ProductCard';
import { Button } from '@/components/ui/button';
import { normalize } from '@/utils/format';
export default function CatalogPage() {
  const [params, setParams] = useSearchParams();
  const [mobile, setMobile] = useState(false);
  const products = useProducts();
  const categories = useCategories();
  const q = params.get('q') || '';
  const category = params.get('category') || '';
  const requestedSort = params.get('sort') || 'popular';
  const sort = requestedSort === 'newest' ? 'expiry' : requestedSort;
  const sale = params.get('sale') === '1';
  const page = Math.max(1, Number(params.get('page')) || 1);
  const brand = params.get('brand') || '';
  const price = params.get('price') || '';
  const inStock = params.get('stock') === '1';
  const set = (key, value) => {
    const next = new URLSearchParams(params);
    value ? next.set(key, value) : next.delete(key);
    if (key !== 'page') next.delete('page');
    setParams(next);
  };
  let filtered = (products.data || []).filter(
    (p) =>
      (!q || normalize(p.name + ' ' + p.brand).includes(normalize(q))) &&
      (!category || p.categoryId === category) &&
      (!brand || p.brand === brand) &&
      (!sale || p.originalPrice > p.price) &&
      (!inStock || canPurchase(p)) &&
      (!price ||
        (price === 'under10'
          ? p.price < 10000
          : price === '10to20'
            ? p.price >= 10000 && p.price <= 20000
            : p.price > 20000)),
  );
  filtered =
    sort === 'expiry'
      ? sortByExpiry(filtered)
      : [...filtered].sort((a, b) =>
          sort === 'price_asc'
            ? a.price - b.price
            : sort === 'price_desc'
              ? b.price - a.price
              : sort === 'name'
                ? a.name.localeCompare(b.name, 'vi')
                : sort === 'newest'
                  ? b.createdAt.localeCompare(a.createdAt)
                  : 0,
        );
  const pages = Math.ceil(filtered.length / 9);
  const current = Math.min(page, pages || 1);
  const brands = [...new Set((products.data || []).map((p) => p.brand))];
  const title = sale
    ? 'Ưu đãi hôm nay'
    : categories.data?.find((c) => c.id === category)?.name || 'Thế giới đồ uống';
  return (
    <div className="container catalog-page">
      <Breadcrumb items={[{ label: 'Sản phẩm' }]} />
      <div className="catalog-banner">
        <div>
          <span className="eyebrow">CHỌN VỊ CỦA RIÊNG BẠN</span>
          <h1>
            {title}
            <span>.</span>
          </h1>
          <p>Mỗi lựa chọn là một cách làm mới ngày của bạn.</p>
        </div>
        <span className="banner-symbol">
          <ArrowUpRight size={68} strokeWidth={0.8} />
        </span>
      </div>
      <div className="catalog-layout">
        <aside className={'filters ' + (mobile ? 'filters-open' : '')}>
          <div className="filter-heading">
            <h3>Bộ lọc sản phẩm</h3>
            <button
              onClick={() => {
                setParams({});
                setMobile(false);
              }}
              className="text-button"
            >
              Đặt lại
            </button>
            <button
              className="icon-button mobile-only"
              aria-label="Đóng bộ lọc"
              onClick={() => setMobile(false)}
            >
              <X size={18} />
            </button>
          </div>
          <fieldset>
            <legend>Loại sản phẩm</legend>
            <label className="radio-row">
              <input
                type="radio"
                name="category"
                checked={!category}
                onChange={() => set('category', '')}
              />
              Tất cả đồ uống <span>{products.data?.length || 0}</span>
            </label>
            {categories.data?.map((c) => (
              <label key={c.id} className="radio-row">
                <input
                  type="radio"
                  name="category"
                  checked={category === c.id}
                  onChange={() => set('category', c.id)}
                />
                {c.name}
                <span>{products.data?.filter((p) => p.categoryId === c.id).length || 0}</span>
              </label>
            ))}
          </fieldset>
          <fieldset>
            <legend>Khoảng giá</legend>
            {[
              ['', 'Tất cả mức giá'],
              ['under10', 'Dưới 10.000đ'],
              ['10to20', '10.000đ – 20.000đ'],
              ['above20', 'Trên 20.000đ'],
            ].map(([value, label]) => (
              <label key={value} className="radio-row">
                <input
                  type="radio"
                  name="price"
                  checked={price === value}
                  onChange={() => set('price', value)}
                />
                {label}
              </label>
            ))}
          </fieldset>
          <fieldset>
            <legend>Thương hiệu</legend>
            <select
              aria-label="Lọc thương hiệu"
              value={brand}
              onChange={(e) => set('brand', e.target.value)}
            >
              <option value="">Tất cả thương hiệu</option>
              {brands.map((b) => (
                <option key={b}>{b}</option>
              ))}
            </select>
          </fieldset>
          <fieldset>
            <legend>Lựa chọn khác</legend>
            <label className="radio-row">
              <input
                type="checkbox"
                checked={sale}
                onChange={(e) => set('sale', e.target.checked ? '1' : '')}
              />
              Đang có ưu đãi
            </label>
            <label className="radio-row">
              <input
                type="checkbox"
                checked={inStock}
                onChange={(e) => set('stock', e.target.checked ? '1' : '')}
              />
              Chỉ xem còn hàng
            </label>
          </fieldset>
        </aside>
        <section>
          <div className="catalog-toolbar">
            <form className="catalog-search" onSubmit={(e) => e.preventDefault()}>
              <Search size={18} />
              <input
                aria-label="Tìm kiếm sản phẩm"
                value={q}
                onChange={(e) => set('q', e.target.value)}
                placeholder="Tìm đồ uống yêu thích…"
              />
            </form>
            <button className="btn btn-outline mobile-only" onClick={() => setMobile(!mobile)}>
              <SlidersHorizontal size={16} />
              Lọc
            </button>
            <select
              aria-label="Sắp xếp sản phẩm"
              value={sort}
              onChange={(e) => set('sort', e.target.value)}
            >
              <option value="popular">Gợi ý cho bạn</option>
              <option value="expiry">Mới Nhất</option>
              <option value="price_asc">Giá thấp đến cao</option>
              <option value="price_desc">Giá cao đến thấp</option>
              <option value="name">Tên A – Z</option>
            </select>
          </div>
          <div className="result-count">
            <strong>{filtered.length}</strong> sản phẩm {q && <span>cho “{q}”</span>}
          </div>
          <QueryState query={products} cards>
            {filtered.length ? (
              <>
                <div className="product-grid catalog-grid">
                  {filtered.slice((current - 1) * 9, current * 9).map((p) => (
                    <ProductCard key={p.id} product={p} />
                  ))}
                </div>
                <Pagination
                  page={current}
                  pages={pages}
                  onChange={(p) => {
                    set('page', String(p));
                    window.scrollTo({ top: 180, behavior: 'smooth' });
                  }}
                />
              </>
            ) : (
              <EmptyState
                title="Chưa tìm được vị bạn muốn"
                description="Thử từ khóa khác hoặc điều chỉnh bộ lọc."
                action={<Button onClick={() => setParams({})}>Xem tất cả sản phẩm</Button>}
              />
            )}
          </QueryState>
          {categories.isError && (
            <p role="alert">
              Không tải được danh mục. <button onClick={() => categories.refetch()}>Thử lại</button>
            </p>
          )}
        </section>
      </div>
    </div>
  );
}
