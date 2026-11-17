import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowUpRight, ChevronLeft, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { HeroArtwork } from './DrinkArt';

const slides = [
  {
    eyebrow: 'TRẠM TIẾP NƯỚC CỦA BẠN',
    title: 'Một ngụm tươi mới.',
    emphasis: 'Cả ngày hứng khởi.',
    description:
      'Từ vị quen thân thuộc đến những lựa chọn mới mẻ. Tìm thức uống yêu thích, để WaterBus lo phần còn lại.',
    action: 'Khám phá ngay',
    to: '/products',
    theme: 'original',
  },
  {
    eyebrow: 'CHẠM VỊ TRÁI CÂY',
    title: 'Bật nắp tươi mát.',
    emphasis: 'Đánh thức ngày vui.',
    description: 'Thêm chút sắc màu cho giờ nghỉ với những thức uống trái cây yêu thích.',
    action: 'Chọn vị yêu thích',
    to: '/products',
    theme: 'citrus',
    image: '/posters/citrus.svg',
    alt: 'Poster hai chai nước trái cây WaterBus cùng lát cam và lá xanh',
  },
  {
    eyebrow: 'MỘT KHOẢNG NGHỈ CHO BẠN',
    title: 'Chậm một chút.',
    emphasis: 'Thêm chút đậm đà.',
    description: 'Tìm một thức uống vừa ý, tận hưởng khoảnh khắc nhỏ giữa ngày bận rộn.',
    action: 'Xem bộ sưu tập',
    to: '/products',
    theme: 'coffee',
    image: '/posters/coffee.svg',
    alt: 'Poster cà phê và sữa WaterBus trên nền kem với hạt cà phê',
  },
];

export default function HomeCarousel() {
  const [index, setIndex] = useState(0);
  const slide = slides[index];
  const move = (step) => setIndex((current) => (current + step + slides.length) % slides.length);
  return (
    <section
      className={`hero home-carousel carousel-${slide.theme}`}
      aria-label="Bộ sưu tập WaterBus"
      aria-roledescription="băng chuyền"
    >
      {slides.map((item, position) => (
        <div
          key={item.theme}
          className="carousel-slide"
          aria-hidden={index !== position}
          inert={index !== position ? '' : undefined}
          style={{ visibility: index === position ? 'visible' : 'hidden' }}
        >
          <div
            className="hero-copy"
            aria-live={index === position ? 'polite' : 'off'}
            aria-atomic="true"
          >
            <span className="hero-eyebrow">
              <span />
              {item.eyebrow}
            </span>
            <h1>
              {item.title}
              <br />
              <em>{item.emphasis}</em>
            </h1>
            <p>{item.description}</p>
            <Button asChild size="lg">
              <Link to={item.to}>
                {item.action}
                <ArrowUpRight size={19} />
              </Link>
            </Button>
          </div>
          {item.image ? (
            <div className="carousel-poster">
              <img key={item.image} src={item.image} alt={item.alt} width="640" height="560" />
            </div>
          ) : (
            <HeroArtwork />
          )}
        </div>
      ))}
      <div className="carousel-controls">
        <button
          type="button"
          className="carousel-arrow"
          aria-label="Poster trước"
          onClick={() => move(-1)}
        >
          <ChevronLeft size={20} />
        </button>
        <div className="carousel-dots" aria-label="Chọn poster">
          {slides.map((item, position) => (
            <button
              key={item.theme}
              type="button"
              aria-label={`Xem poster ${position + 1}`}
              aria-current={index === position ? 'true' : undefined}
              onClick={() => setIndex(position)}
            />
          ))}
        </div>
        <button
          type="button"
          className="carousel-arrow"
          aria-label="Poster tiếp theo"
          onClick={() => move(1)}
        >
          <ChevronRight size={20} />
        </button>
        <span className="carousel-counter" aria-live="polite">
          0{index + 1} / 0{slides.length}
        </span>
      </div>
    </section>
  );
}
