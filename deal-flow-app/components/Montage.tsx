'use client'

type Tile = { src: string, alt?: string }
export default function Montage({ tiles }: { tiles: Tile[] }) {
  // Only display up to six tiles. Additional images are ignored on the cover page.
  const shown = tiles.slice(0, 6)
  return (
    <div className="grid grid-cols-3 gap-2">
      {shown.map((tile, index) => (
        <div
          key={index}
          className="relative w-full h-36 md:h-48 rounded-lg overflow-hidden border"
        >
          {/* Image itself */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={tile.src}
            alt={tile.alt || ''}
            className="w-full h-full object-cover"
          />
          {/* Optional caption overlay. Use alt as the caption if provided */}
          {tile.alt && (
            <div className="absolute bottom-0 left-0 right-0 bg-black bg-opacity-50 text-white text-xs p-1 truncate">
              {tile.alt}
            </div>
          )}
        </div>
      ))}
    </div>
  )
}
