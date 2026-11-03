import { canPurchase } from '@/utils/inventory';
import { useParams, Link } from 'react-router-dom';
import { useState } from 'react';
import { ShoppingBag, Truck, Leaf, ArrowRight } from 'lucide-react';
import { useProduct, useProducts, useCategories } from '@/hooks/useData';
import { useCart } from '@/contexts/CartContext';
import { Breadcrumb, QueryState, Quantity, SectionHeading } from '@/components/common/Shared';
import { Button } from '@/components/ui/button';
import { DrinkArt } from '@/components/customer/DrinkArt';
import { ProductCard } from '@/components/customer/ProductCard';
import { purchaseUnits, purchaseUnit } from '@/utils/purchase';
import { money } from '@/utils/format';
function ProductDetail({ product }) {
  const [quantity, setQuantity] = useState(1);
  const [unit, setUnit] = useState('single');
  const [tab, setTab] = useState('description');
  const { add } = useCart();
  const products = useProducts();
  const categories = useCategories();
  const p = product;
  const chosen = purchaseUnit(p, unit);
  const available = canPurchase(p);
  const max = available ? Math.floor(p.stock / chosen.size) : 0;
  return (
    <>
      <Breadcrumb items={[{ label: 'Sản phẩm', to: '/products' }, { label: p.name }]} />
      <section className="product-detail">
        <div
          className={'detail-art' + (!available ? ' is-unavailable' : '')}
          style={{ background: p.accent }}
        >
          <DrinkArt product={p} hero />
        </div>
        <div className="detail-copy">
          <span className="eyebrow">
            {categories.data?.find((c) => c.id === p.categoryId)?.name || 'ĐỒ UỐNG'} / {p.brand}
          </span>
          <h1>{p.name}</h1>
          <p className="detail-volume">
            {p.volume} <span>·</span> Mã sản phẩm: {p.id.toUpperCase()}
          </p>
          <div className="detail-price">
            <strong>{money(chosen.price)}</strong>
            <small>/ {chosen.label.toLowerCase()}</small>
            {p.originalPrice > p.price && (
              <>
                <del>{money(p.originalPrice * chosen.size)}</del>
                <span>Tiết kiệm {money(p.originalPrice * chosen.size - chosen.price)}</span>
              </>
            )}
          </div>
          <p>{p.description}</p>
          <div className={'stock-label ' + (!available ? 'stock-empty' : '')}>
            <i />
            {available ? 'Còn hàng — ' + p.stock + ' sản phẩm' : 'Tạm hết hàng'}
          </div>
          <label className="purchase-unit">
            Đơn vị mua
            <select
              aria-label="Đơn vị mua"
              value={unit}
              onChange={(e) => {
                setUnit(e.target.value);
                setQuantity(1);
              }}
            >
              {purchaseUnits(p).map((u) => (
                <option key={u.id} value={u.id} disabled={!available || p.stock < u.size}>
                  {u.label}
                  {u.size > 1
                    ? ' (' + u.size + ' ' + purchaseUnit(p).label.toLowerCase() + ')'
                    : ''}
                </option>
              ))}
            </select>
          </label>
          {unit !== 'single' && (
            <p className="package-savings">
              {unit === 'pack'
                ? 'Lốc 6: giảm 10% so với mua lẻ.'
                : 'Thùng 24: giảm thêm 10% so với mua 4 lốc (giảm 19% so với mua lẻ).'}
            </p>
          )}
          <div className="purchase-row">
            <Quantity value={quantity} max={max} onChange={setQuantity} />
            <Button disabled={max < 1} onClick={() => add(p, quantity, unit)}>
              <ShoppingBag size={18} />
              {available ? 'Thêm vào giỏ hàng' : 'Tạm hết hàng'}
            </Button>
          </div>
          <Link to="/cart" className="text-link">
            Xem giỏ hàng <ArrowRight size={16} />
          </Link>
          <div className="detail-perks">
            <span>
              <Truck size={19} />
              Phí giao hàng 20.000đ
            </span>
          </div>
        </div>
      </section>
      <section className="product-tabs">
        <div className="tabs" role="tablist">
          {[
            ['description', 'Mô tả sản phẩm'],
            ['information', 'Thông tin chi tiết'],
          ].map(([id, label]) => (
            <button
              key={id}
              role="tab"
              aria-selected={tab === id}
              onClick={() => setTab(id)}
              className={tab === id ? 'active' : ''}
            >
              {label}
            </button>
          ))}
        </div>
        <div className="tab-panel" role="tabpanel">
          {tab === 'description' ? (
            <>
              <h3>{p.name}</h3>
              <p>{p.description}</p>
              <p>
                Bảo quản nơi khô ráo, thoáng mát. Thông tin thành phần, dinh dưỡng và hạn sử dụng
                vui lòng xem trên bao bì sản phẩm.
              </p>
            </>
          ) : (
            <dl className="spec-list">
              {[
                ['Thương hiệu', p.brand],
                ['Quy cách', p.volume],
                ['Tình trạng', available ? 'Còn hàng' : 'Tạm hết hàng'],
              ].map(([k, v]) => (
                <div key={k}>
                  <dt>{k}</dt>
                  <dd>{v}</dd>
                </div>
              ))}
            </dl>
          )}
        </div>
      </section>
      <section className="related-section">
        <SectionHeading
          title="Thêm một lựa chọn hợp gu"
          to={'/products?category=' + p.categoryId}
        />
        <div className="product-grid">
          {products.data
            ?.filter((item) => item.categoryId === p.categoryId && item.id !== p.id)
            .slice(0, 4)
            .map((item) => (
              <ProductCard key={item.id} product={item} />
            ))}
        </div>
      </section>
    </>
  );
}
export default function ProductPage() {
  const { id } = useParams();
  const query = useProduct(id);
  return (
    <div className="container product-page">
      <QueryState query={query}>
        {query.data && <ProductDetail key={id} product={query.data} />}
      </QueryState>
    </div>
  );
}
