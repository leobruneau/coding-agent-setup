import { expect, test } from 'claude-code/testing'

import { k, level } from './register'

test('format', () => {
  expect(k(999)).toBe('999')
  expect(k(123456)).toBe('123.5K')
  expect(k(70000)).toBe('70.0K')
})

test('level', () => {
  expect(level(70_000)).toBe('success')
  expect(level(70_001)).toBe('warning')
  expect(level(140_000)).toBe('warning')
  expect(level(140_001)).toBe('error')
})
