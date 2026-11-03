import { canPurchase } from '@/utils/inventory';
import { Link } from 'react-router-dom';
import { Plus, Check, ArrowUpRight } from 'lucide-react';
import { DrinkArt } from './DrinkArt';
import { useCart } from '@/contexts/CartContext';
import { money } from '@/utils/format';
export function ProductCard({ product }) {
  const { add, items } = useCart();
  const inCart = items.some((p) => p.productId === product.id);
  const unavailable = !canPurchase(product);
  const sale = product.originalPrice > product.price;
  return (
    <article className={'product-card' + (unavailable ? ' is-unavailable' : '')}>
      <Link
        to={'/products/' + product.id}
        className="product-image"
        style={{ '--product-tint': product.accent }}
        aria-label={'Xem ' + product.name}
      >
        {sale ? (
          <span className="product-tag sale">
            −{Math.round((1 - product.price / product.originalPrice) * 100)}%
          </span>
        ) : (
          product.tag && <span className="product-tag">{product.tag}</span>
        )}
        <DrinkArt product={product} />
        <span className="product-view">
          <ArrowUpRight size={18} />
        </span>
        {unavailable && <span className="out-stock">Tạm hết hàng</span>}
      </Link>
      <div className="product-info">
        <div className="product-meta">
          <span>{product.brand}</span>
          <span>{product.volume}</span>
        </div>
        <Link to={'/products/' + product.id} className="product-name">
          {product.name}
        </Link>
        <div className="product-bottom">
          <div>
            <strong>{money(product.price)}</strong>
            {sale && <del>{money(product.originalPrice)}</del>}
          </div>
          <button
            className={'add-button ' + (inCart ? 'in-cart' : '')}
            disabled={unavailable}
            onClick={() => add(product)}
            aria-label={'Thêm ' + product.name + ' vào giỏ'}
          >
            {inCart ? <Check size={19} /> : <Plus size={20} />}
          </button>
        </div>
      </div>
    </article>
  );
}
