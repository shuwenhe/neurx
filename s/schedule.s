package neurx.schedule
struct op {
    string name
}

struct scheduler {
}

func run(op op_item) () {
    println("schedule.run: ", op_item.name)
}

