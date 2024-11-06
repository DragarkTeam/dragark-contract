mod models {
    mod achievement;
    mod base;
    mod dragon;
    mod island;
    mod journey;
    mod map;
    mod mission;
    mod player;
    mod position;
    mod scout;
    mod shield;
    mod treasure_hunt;
}

mod systems {
    mod achievement {
        mod contracts;
    }
    mod base {
        mod contracts;
    }
    mod dragon {
        mod contracts;
    }
    mod island {
        mod contracts;
    }
    mod journey {
        mod contracts;
    }
    mod map {
        mod contracts;
    }
    mod mission {
        mod contracts;
    }
    mod player {
        mod contracts;
    }
    mod scout {
        mod contracts;
    }
    mod shield {
        mod contracts;
    }
    mod treasure_hunt {
        mod contracts;
    }
}

mod utils {
    mod general;
    #[cfg(test)]
    mod testing;
}

mod constants;
mod errors;
mod events;
