'use client'
export default function PrintButton() {
  return <button onClick={()=>window.print()} className="px-4 py-2 rounded bg-wraBlue text-white">Print Tour Book</button>
}
