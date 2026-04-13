-- Species ID → sprite configuration.
-- Enhanced sprites are 32×32 RGBA with 11 frames (4 idle + 3 attack + 2 hit + 2 faint).
-- Placeholder sprites are 32×32 RGBA with 2 frames.

local M = {}

local ANIMS = {
  idle   = { frames = {0, 1}, speed = 0.5, loop = true  },
  attack = { frames = {0},    speed = 0.0, loop = false },
  hit    = { frames = {1},    speed = 0.0, loop = false },
  faint  = { frames = {1},    speed = 0.0, loop = false, stay_on_last = true },
}

local function entry(filename, anims)
  return {
    path = "assets/sprites/" .. filename .. ".png",
    frame_w = 32, frame_h = 32, scale = 1,
    animations = anims or ANIMS,
  }
end

-- Common base forms
M.println    = entry("println", {
  idle   = { frames = {0,1,2,3},  speed = 0.4,  loop = true },
  attack = { frames = {4,5,6},    speed = 0.12, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.glitch     = entry("glitch", {
  idle   = { frames = {0,1,2,3},  speed = 0.35, loop = true },
  attack = { frames = {4,5,6},    speed = 0.1,  loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M["goto"]    = entry("goto", {
  idle   = { frames = {0,1,2,3},  speed = 0.45, loop = true },
  attack = { frames = {4,5,6},    speed = 0.15, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.monad      = entry("monad", {
  idle   = { frames = {0,1,2,3},  speed = 0.45, loop = true },
  attack = { frames = {4,5,6},    speed = 0.15, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.copilot    = entry("copilot", {
  idle   = { frames = {0,1,2,3},  speed = 0.35, loop = true },
  attack = { frames = {4,5,6},    speed = 0.12, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.segfault   = entry("segfault", {
  idle   = { frames = {0,1,2,3},  speed = 0.35, loop = true },
  attack = { frames = {4,5,6},    speed = 0.12, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.mutex      = entry("mutex", {
  idle   = { frames = {0,1,2,3},  speed = 0.5,  loop = true },
  attack = { frames = {4,5,6},    speed = 0.15, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.lgtm       = entry("lgtm", {
  idle   = { frames = {0,1,2,3},  speed = 0.4,  loop = true },
  attack = { frames = {4,5,6},    speed = 0.12, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.singleton  = entry("singleton", {
  idle   = { frames = {0,1,2,3},  speed = 0.45, loop = true },
  attack = { frames = {4,5,6},    speed = 0.15, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.printf     = entry("printf", {
  idle   = { frames = {0,1,2,3},  speed = 0.4,  loop = true },
  attack = { frames = {4,5,6},    speed = 0.12, loop = false },
  hit    = { frames = {7,8},      speed = 0.15, loop = false },
  faint  = { frames = {9,10},     speed = 0.3,  loop = false, stay_on_last = true },
})

-- Common evolutions
M.tracer         = entry("tracer", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.4,  loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.gremlin        = entry("gremlin", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.35, loop = true },
  attack = { frames = {5,6,7},      speed = 0.1,  loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.spaghetto      = entry("spaghetto", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.45, loop = true },
  attack = { frames = {5,6,7},      speed = 0.15, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.functor        = entry("functor", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.45, loop = true },
  attack = { frames = {5,6,7},      speed = 0.15, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.autopilot      = entry("autopilot", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.35, loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.stack_overflow = entry("stack_overflow", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.35, loop = true },
  attack = { frames = {5,6,7},      speed = 0.1,  loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.god_object     = entry("god_object", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.45, loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.semaphore      = entry("semaphore", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.5,  loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.nitpick        = entry("nitpick", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.4,  loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})
M.fprintf        = entry("fprintf", {
  idle   = { frames = {0,1,2,3,4},  speed = 0.4,  loop = true },
  attack = { frames = {5,6,7},      speed = 0.12, loop = false },
  hit    = { frames = {8,9},        speed = 0.15, loop = false },
  faint  = { frames = {10,11},      speed = 0.3,  loop = false, stay_on_last = true },
})

-- Uncommon final forms
M.pandemonium        = entry("pandemonium", {
  idle   = { frames = {0,1,2,3,4,5},  speed = 0.35, loop = true },
  attack = { frames = {6,7,8},        speed = 0.12, loop = false },
  hit    = { frames = {9,10},         speed = 0.15, loop = false },
  faint  = { frames = {11,12,13},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.dependency         = entry("dependency", {
  idle   = { frames = {0,1,2,3,4,5},  speed = 0.45, loop = true },
  attack = { frames = {6,7,8},        speed = 0.15, loop = false },
  hit    = { frames = {9,10},         speed = 0.15, loop = false },
  faint  = { frames = {11,12,13},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.profiler           = entry("profiler", {
  idle   = { frames = {0,1,2,3,4,5},  speed = 0.4,  loop = true },
  attack = { frames = {6,7,8},        speed = 0.12, loop = false },
  hit    = { frames = {9,10},         speed = 0.15, loop = false },
  faint  = { frames = {11,12,13},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.logstash           = entry("logstash", {
  idle   = { frames = {0,1,2,3,4,5},  speed = 0.4,  loop = true },
  attack = { frames = {6,7,8},        speed = 0.15, loop = false },
  hit    = { frames = {9,10},         speed = 0.15, loop = false },
  faint  = { frames = {11,12,13},     speed = 0.3,  loop = false, stay_on_last = true },
})
M.kernel_panic_critter = entry("kernel_panic_critter", {
  idle   = { frames = {0,1,2,3,4,5},  speed = 0.35, loop = true },
  attack = { frames = {6,7,8},        speed = 0.1,  loop = false },
  hit    = { frames = {9,10},         speed = 0.15, loop = false },
  faint  = { frames = {11,12,13},     speed = 0.3,  loop = false, stay_on_last = true },
})
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
    frame_w = 32, frame_h = 32, scale = 1,
    animations = ANIMS,
  }
end

return M
