import { useId } from 'react';
export function DrinkArt({ product, className = '', hero = false }) {
  const id = useId().replace(/:/g, '');
  const p = product || {
    art: 'can',
    color: '#df772e',
    accent: '#fff3cd',
    label: 'waterbus',
    volume: 'CAM • 330 ml',
  };
  if (p.imageUrl)
    return (
      <img
        className={'drink-art ' + className}
        src={p.imageUrl}
        alt={p.name}
        loading={hero ? 'eager' : 'lazy'}
        style={{ objectFit: 'contain' }}
      />
    );
  const bottle = p.art === 'bottle' || p.art === 'water';
  const carton = p.art === 'carton';
  return (
    <svg
      className={'drink-art ' + className}
      viewBox="0 0 200 280"
      role="img"
      aria-label={'Minh họa bao bì ' + (p.name || 'WaterBus')}
    >
      <defs>
        <linearGradient id={id + 'g'}>
          <stop offset="0" stopColor={p.color} />
          <stop offset=".27" stopColor={p.accent} stopOpacity=".55" />
          <stop offset=".5" stopColor={p.color} />
          <stop offset="1" stopColor="#17291c" stopOpacity=".6" />
        </linearGradient>
        <linearGradient id={id + 's'} x2="0" y2="1">
          <stop stopColor="#f4f2e4" />
          <stop offset=".45" stopColor="#b8b9af" />
          <stop offset=".65" stopColor="#f9f8e8" />
          <stop offset="1" stopColor="#999d95" />
        </linearGradient>
        <linearGradient id={id + 'l'}>
          <stop stopColor="white" stopOpacity=".7" />
          <stop offset="1" stopColor="white" stopOpacity="0" />
        </linearGradient>
        <filter id={id + 'blur'}>
          <feGaussianBlur stdDeviation="5" />
        </filter>
      </defs>
      <ellipse
        cx="101"
        cy="257"
        rx="52"
        ry="10"
        fill="#20372b"
        opacity=".16"
        filter={'url(#' + id + 'blur)'}
      />
      {bottle ? (
        <g>
          <rect x="82" y="18" width="36" height="24" rx="5" fill={p.color} />
          <path
            d="M84 40h32v24c0 19 35 22 35 49v127c0 13-12 19-51 19s-51-6-51-19V113c0-27 35-30 35-49z"
            fill={p.art === 'water' ? '#d8eced' : p.color}
          />
          <path
            d="M84 42h32v24c0 20 32 25 32 48v126c0 12-9 17-48 17s-48-5-48-17V114c0-23 32-28 32-48z"
            fill={'url(#' + id + 'g)'}
            opacity={p.art === 'water' ? '.35' : '1'}
          />
          <rect
            x="49"
            y="126"
            width="102"
            height="79"
            rx="4"
            fill={p.art === 'water' ? '#f1f5ed' : p.accent}
          />
          <path d="M61 110v125" stroke="white" strokeWidth="7" opacity=".2" strokeLinecap="round" />
          <path d="M52 218h96M52 230h96" stroke={p.color} opacity=".35" strokeWidth="3" />
          <text
            x="100"
            y="157"
            textAnchor="middle"
            fill={p.color}
            fontSize={p.label.length > 10 ? 12 : 23}
            fontWeight="800"
            fontFamily="Arial"
          >
            {p.label}
          </text>
          <text x="100" y="179" textAnchor="middle" fill={p.color} fontSize="7" letterSpacing="2">
            {p.art === 'water' ? 'NƯỚC KHOÁNG' : 'TƯƠI MÁT TỰ NHIÊN'}
          </text>
        </g>
      ) : carton ? (
        <g>
          <path d="M56 57l17-28h58l17 28v188H56z" fill={p.accent} />
          <path d="M56 57h70v188H56z" fill={'url(#' + id + 'g)'} />
          <path d="M126 57l22-1v188l-22 1z" fill={p.color} />
          <path d="M56 57l17-28h58l-5 28z" fill="#faf9ef" />
          <path d="M73 29h58" stroke={p.color} strokeWidth="8" />
          <rect x="63" y="102" width="56" height="83" rx="28" fill={p.accent} />
          <text
            x="92"
            y="143"
            textAnchor="middle"
            fill={p.color}
            fontSize={p.label.length > 5 ? 13 : 31}
            fontWeight="800"
            fontFamily="Arial"
          >
            {p.label}
          </text>
          <text x="92" y="162" textAnchor="middle" fill={p.color} fontSize="7">
            TỰ NHIÊN MỖI NGÀY
          </text>
        </g>
      ) : (
        <g>
          <rect x="50" y="33" width="100" height="219" rx="23" fill={'url(#' + id + 's)'} />
          <path d="M51 49q49-9 98 0v184q-49 14-98 0z" fill={p.color} />
          <path d="M51 49q49-9 98 0v184q-49 14-98 0z" fill={'url(#' + id + 'g)'} />
          <path d="M51 170q36-40 98-18v43q-61-18-98 20z" fill={p.accent} opacity=".9" />
          <ellipse cx="100" cy="36" rx="44" ry="6" fill="#d9dcd1" />
          <ellipse cx="100" cy="35" rx="22" ry="4" fill="#9a9e94" />
          <rect x="94" y="29" width="19" height="7" rx="3" fill="#dddeda" />
          <path d="M61 57v166" stroke={'url(#' + id + 'l)'} strokeWidth="9" opacity=".6" />
          <text
            x="100"
            y="117"
            textAnchor="middle"
            fill={p.accent}
            fontSize={p.label.length > 8 ? 13 : 24}
            fontStyle={p.label === 'Coca-Cola' ? 'italic' : 'normal'}
            fontWeight="800"
            fontFamily="Arial"
          >
            {p.label}
          </text>
          <text x="100" y="136" textAnchor="middle" fill={p.accent} fontSize="7" letterSpacing="2">
            TƯƠI MÁT MỖI NGÀY
          </text>
          <text x="100" y="217" textAnchor="middle" fill={p.accent} fontSize="7" letterSpacing="1">
            {p.volume || 'TƯƠI MÁT • 330 ml'}
          </text>
          <path d="M62 241q38 7 76 0" fill="none" stroke="#969b8f" strokeWidth="2" />
        </g>
      )}
      {Array.from({ length: hero ? 25 : 10 }, (_, i) => (
        <ellipse
          key={i}
          cx={58 + ((i * 23) % 84)}
          cy={70 + ((i * 37) % 157)}
          rx={i % 3 === 0 ? 2 : 1.2}
          ry={i % 3 === 0 ? 3 : 1.8}
          fill="#fff"
          opacity=".45"
        />
      ))}
    </svg>
  );
}
export function HeroArtwork() {
  return (
    <div className="hero-artwork" aria-label="Minh họa bộ sưu tập nước giải khát WaterBus">
      <div className="hero-orbit orbit-one" />
      <div className="hero-orbit orbit-two" />
      <span className="hero-spark spark-one">✳</span>
      <span className="hero-spark spark-two">✳</span>
      <div className="fruit fruit-back" />
      <div className="hero-can hero-can-back">
        <DrinkArt
          hero
          product={{
            art: 'can',
            color: '#54826b',
            accent: '#e7f0c8',
            label: 'waterbus',
            volume: 'CHANH • 330 ml',
          }}
        />
      </div>
      <div className="hero-can hero-can-front">
        <DrinkArt
          hero
          product={{
            art: 'can',
            color: '#e7823c',
            accent: '#fff1c4',
            label: 'waterbus',
            volume: 'CAM • 330 ml',
          }}
        />
      </div>
      <div className="fruit fruit-front" />
      <div className="hero-leaf leaf-one" />
      <div className="hero-leaf leaf-two" />
      <div className="hero-sticker">
        <span>100%</span>
        <small>
          TƯƠI MỚI
          <br />
          MỖI NGÀY
        </small>
      </div>
      <span className="art-caption">Bao bì minh họa · Bộ sưu tập cảm hứng</span>
    </div>
  );
}
