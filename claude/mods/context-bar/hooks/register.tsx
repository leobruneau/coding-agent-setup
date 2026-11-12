import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Fill } from '../types'

// Tune these: token counts above which the number turns yellow / red.
const WARN = 70_000
const ALERT = 140_000

const fill = atom({ plugin: 'context-bar', key: 'fill' } as const, null)

export const k = (n: number) => (n >= 1000 ? `${(n / 1000).toFixed(1)}K` : `${n}`)

export const level = (tokens: number) =>
  tokens > ALERT ? 'error' : tokens > WARN ? 'warning' : 'success'

export const register: Register = on => {
  on('session.measure', async ($, e, next) => {
    const { tokens, window, percent } = e.context
    if (tokens !== undefined && percent !== undefined) {
      await update($, fill, () => ({ tokens, window, percent }))
    }

    return next(e)
  })

  // ponytail: no slot under the prompt takes a tree except the footer's mode labels, so the count rides there
  on('ui.render', { component: 'SessionMode' }, async ($, e, next) => {
    const f: Fill | null = await read($, fill)
    if (f === null) return next(e)

    const { Text } = $.ui.resolve(e)

    return (
      <Text>
        {e.props.modes.length > 0 && <Text dimColor>{e.props.modes.join(' & ')} · </Text>}
        <Text bold color={level(f.tokens)}>
          {k(f.tokens)}
        </Text>
        <Text dimColor> ({f.percent}%)</Text>
      </Text>
    )
  })
}
