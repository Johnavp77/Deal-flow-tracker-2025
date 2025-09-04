import { LOITemplate } from './loiTemplates'
export type LOIValues = Record<string, string | number | undefined>
export function mergeTemplate(t: LOITemplate, values: LOIValues): string {
  return t.body.replace(/\{\{([A-Z0-9_]+)\}\}/g, (_, key) => {
    const v = values[key]; return (v === undefined || v === null) ? `[${key}]` : String(v)
  })
}
