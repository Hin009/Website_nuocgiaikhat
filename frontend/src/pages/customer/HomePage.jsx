import { Link } from 'react-router-dom';
import {
  ArrowRight,
  ArrowUpRight,
  Sparkles,
  Citrus,
  Coffee,
  Droplets,
  Milk,
  Zap,
  CupSoda,
  Leaf,
  Check,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { SectionHeading, QueryState } from '@/components/common/Shared';
import { HeroArtwork, DrinkArt } from '@/components/customer/DrinkArt';
import { ProductCard } from '@/components/customer/ProductCard';
import { useProducts, useCategories } from '@/hooks/useData';
const icons = {
  cup: CupSoda,
  citrus: Citrus,
  water: Droplets,
  coffee: Coffee,
  zap: Zap,
  milk: Milk,
};
export default function HomePage() {
  const products = useProducts();
  const categories = useCategories();
  return (
    <>
      <div className="container home-content">
        <section className="hero">
          <div className="hero-copy">
            <span className="hero-eyebrow">
              <span /> TRẠM TIẾP NƯỚC CỦA BẠN
            </span>
            <h1>
              Một ngụm tươi mới.
              <br />
              Cả ngày <em>hứng khởi.</em>
            </h1>
            <p>
              Từ vị quen thân thuộc đến những lựa chọn mới mẻ.
              <br className="desktop-break" /> Tìm thức uống yêu thích, để WaterBus lo phần còn lại.
            </p>
            <Button asChild size="lg">
              <Link to="/products">
                Khám phá ngay <ArrowUpRight size={19} />
              </Link>
            </Button>
            <div className="hero-proof">
              <div className="avatar-stack">
                <span>AN</span>
                <span>MY</span>
                <span>HN</span>
                <span>+</span>
              </div>
              <div>
                <strong>Đồ uống ngon, ngày thêm vui</strong>
                <small>Khám phá bộ sưu tập dành cho bạn</small>
              </div>
            </div>
          </div>
          <HeroArtwork />
        </section>
        <div className="home-demo">
          <span>Chọn vị bạn thích. Bắt đầu một ngày thật khác.</span>
        </div>
        <section className="category-section">
          <SectionHeading eyebrow="TÌM CHÚT TƯƠI MÁT" title="Bạn muốn uống gì hôm nay?" />
          <QueryState query={categories}>
            <div className="category-grid">
              {categories.data?.map((c) => {
                const Icon = icons[c.icon] || CupSoda;
                return (
                  <Link key={c.id} className="category-card" to={'/products?category=' + c.id}>
                    <span className="category-icon" style={{ background: c.color }}>
                      <Icon size={31} strokeWidth={1.4} />
                    </span>
                    <h3>{c.name}</h3>
                    <small>{c.description}</small>
                  </Link>
                );
              })}
            </div>
          </QueryState>
        </section>
        <section className="featured-section">
          <SectionHeading
            eyebrow="ĐƯỢC YÊU THÍCH"
            title="Những vị ngon quen thuộc"
            description="Lựa chọn nổi bật trong bộ sưu tập của WaterBus."
            to="/products"
          />
          <QueryState query={products} cards>
            <div className="product-grid">
              {products.data?.slice(0, 8).map((p) => (
                <ProductCard key={p.id} product={p} />
              ))}
            </div>
          </QueryState>
        </section>
        <section className="promo-grid">
          <Link to="/products?category=juice" className="promo-card promo-orange">
            <div>
              <span className="eyebrow">VỊ NGON TỪ THIÊN NHIÊN</span>
              <h2>
                Thêm chút trái cây.
                <br />
                Thêm nhiều tươi mới.
              </h2>
              <span className="promo-link">
                Khám phá nước trái cây <ArrowRight size={17} />
              </span>
            </div>
            <DrinkArt
              product={{
                art: 'bottle',
                color: '#e5a333',
                accent: '#fff6c9',
                label: 'twister',
                name: 'Nước trái cây',
              }}
            />
            <Citrus className="promo-fruit" size={110} strokeWidth={1} />
          </Link>
          <Link to="/products?sale=1" className="promo-card promo-green">
            <div>
              <span className="eyebrow">MUA VUI, TIẾT KIỆM HƠN</span>
              <h2>
                Vị yêu thích.
                <br />
                Giá thêm xinh.
              </h2>
              <span className="promo-link">
                Xem sản phẩm ưu đãi <ArrowRight size={17} />
              </span>
            </div>
            <DrinkArt
              product={{
                art: 'can',
                color: '#5b8c6b',
                accent: '#e7efc8',
                label: 'waterbus',
                name: 'Nước giải khát',
              }}
            />
            <Sparkles className="promo-spark" size={60} strokeWidth={1} />
          </Link>
        </section>
        <section className="new-section">
          <SectionHeading
            eyebrow="THỬ MỘT CHÚT KHÁC BIỆT"
            title="Mới lên kệ, chờ bạn thử"
            to="/products?sort=newest"
          />
          <QueryState query={products} cards>
            <div className="product-grid">
              {products.data
                ?.filter((p) => p.tag === 'Mới về')
                .slice(0, 4)
                .map((p) => (
                  <ProductCard key={p.id} product={p} />
                ))}
            </div>
          </QueryState>
        </section>
        <section className="story-banner">
          <div className="story-visual">
            <Leaf size={75} strokeWidth={0.9} />
            <span>
              vị ngon.
              <br />
              ngày vui.
            </span>
            <i>waterbus.</i>
          </div>
          <div className="story-copy">
            <span className="eyebrow">KHÔNG CHỈ LÀ ĐỒ UỐNG</span>
            <h2>
              Một trạm nhỏ.
              <br />
              Thật nhiều niềm vui.
            </h2>
            <p>
              Chúng tôi tin rằng một thức uống hợp vị có thể làm ngày của bạn dễ chịu hơn. WaterBus
              là nơi bạn tìm thấy những lựa chọn thân quen, và cả cảm hứng để thử một điều mới.
            </p>
            <div className="story-checks">
              <span>
                <Check size={15} /> Lựa chọn đa dạng
              </span>
              <span>
                <Check size={15} /> Mua sắm dễ dàng
              </span>
            </div>
            <Link className="text-link" to="/about">
              Câu chuyện của chúng tôi <ArrowRight size={17} />
            </Link>
          </div>
        </section>
      </div>
    </>
  );
}
