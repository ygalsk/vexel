-- Species ID → sprite configuration.
-- All placeholder sprites are 32×16 RGBA with 2 frames.

local M = {}

local ANIMS = {
  idle   = { frames = {0, 1}, speed = 0.5, loop = true  },
  attack = { frames = {0},    speed = 0.0, loop = false },
  hit    = { frames = {1},    speed = 0.0, loop = false },
  faint  = { frames = {1},    speed = 0.0, loop = false },
}

local function entry(filename)
  return {
    path = "assets/sprites/" .. filename .. ".png",
    frame_w = 32, frame_h = 16, scale = 2,
    animations = ANIMS,
  }
end

-- Common base forms
M.println    = entry("println")
M.glitch     = entry("glitch")
M["goto"]    = entry("goto")
M.monad      = entry("monad")
M.copilot    = entry("copilot")
M.segfault   = entry("segfault")
M.mutex      = entry("mutex")
M.lgtm       = entry("lgtm")
M.singleton  = entry("singleton")
M.printf     = entry("printf")

-- Common evolutions
M.tracer         = entry("tracer")
M.gremlin        = entry("gremlin")
M.spaghetto      = entry("spaghetto")
M.functor        = entry("functor")
M.autopilot      = entry("autopilot")
M.stack_overflow = entry("stack_overflow")
M.god_object     = entry("god_object")
M.semaphore      = entry("semaphore")
M.nitpick        = entry("nitpick")
M.fprintf        = entry("fprintf")

-- Uncommon final forms
M.pandemonium        = entry("pandemonium")
M.dependency         = entry("dependency")
M.profiler           = entry("profiler")
M.logstash           = entry("logstash")
M.kernel_panic_critter = entry("kernel_panic_critter")
M.monolith           = entry("monolith")
M.deadlock           = entry("deadlock")
M.burrito            = entry("burrito")
M.bikeshed           = entry("bikeshed")
M.hallucination      = entry("hallucination")
M.todo               = entry("todo")
M.readme             = entry("readme")
M.makefile           = entry("makefile")

-- Uncommon mid-tier (evolve into rares)
M.breakpoint     = entry("breakpoint")
M.fuzzer         = entry("fuzzer")
M.queue          = entry("queue")
M.hashmap        = entry("hashmap")

-- Rare final forms
M.watchpoint     = entry("watchpoint")
M.chaos_monkey   = entry("chaos_monkey")
M.priority_queue = entry("priority_queue")
M.b_tree         = entry("b_tree")
M.fixme          = entry("fixme")
M.no_tests       = entry("no_tests")
M.jenkins        = entry("jenkins")
M.heisenbug      = entry("heisenbug")
M.bobby_tables   = entry("bobby_tables")
M.cron           = entry("cron")
M.rubber_duck    = entry("rubber_duck")
M.four_oh_four   = entry("four_oh_four")
M.yolo           = entry("yolo")
M.cobol          = entry("cobol")

-- Epic
M.valgrind        = entry("valgrind")
M.race_condition  = entry("race_condition")
M.load_balancer   = entry("load_balancer")
M.turing_machine  = entry("turing_machine")
M.regex           = entry("regex")
M.prompt_engineer = entry("prompt_engineer")
M.mainframe       = entry("mainframe")

-- Legendary
M.root     = entry("root")
M.zero_day = entry("zero_day")
M.linus    = entry("linus")

function M.get(species_id)
  return M[species_id] or {
    path = nil,
    frame_w = 32, frame_h = 16, scale = 2,
    animations = ANIMS,
  }
end

return M
