-- Step sequencer for battle animations.
-- Queue of {fn, delay} pairs that execute in order during update(dt).

local M = {}

function M.new()
  return { queue = {}, timer = 0, done = false }
end

function M.push(seq, fn, delay)
  table.insert(seq.queue, { fn = fn, delay = delay or 0 })
end

function M.update(seq, dt)
  if seq.done then return true end
  if #seq.queue == 0 then seq.done = true; return true end

  local step = seq.queue[1]
  if not step.started then
    step.fn()
    step.started = true
  end
  seq.timer = seq.timer + dt
  if seq.timer >= step.delay then
    seq.timer = 0
    table.remove(seq.queue, 1)
  end
  return false
end

function M.skip(seq)
  seq.timer = 999
end

return M
