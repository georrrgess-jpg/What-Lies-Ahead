class_name BuildQueue
extends Node
## Runs queued jobs a few per frame, so building a screen full of cards never
## costs one frame more than BUDGET_MS. Every frame runs at least one job;
## keep each job small (a card or a few). Pages use one to fill themselves
## while their slide-in plays; the menu shell uses one to build the pages
## nobody has opened yet while the home screen idles.
##
##   var q := BuildQueue.new()
##   add_child(q)
##   for it in items:
##       q.add(_add_card.bind(it))
##   q.add(_after_cards)

signal drained

## Milliseconds of jobs per frame (the first job of a frame always runs).
const BUDGET_MS := 6.0

var _jobs: Array[Callable] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(not _jobs.is_empty())


## Queues `job` after the others.
func add(job: Callable) -> void:
	_jobs.append(job)
	set_process(true)


## Drops every job not run yet.
func clear() -> void:
	_jobs.clear()
	set_process(false)


func is_idle() -> bool:
	return _jobs.is_empty()


## Runs every queued job now (when something needs the result this frame).
func flush() -> void:
	while not _jobs.is_empty():
		_jobs.pop_front().call()
	set_process(false)


func _process(_delta: float) -> void:
	var start := Time.get_ticks_usec()
	while not _jobs.is_empty():
		var job: Callable = _jobs.pop_front()
		if job.is_valid():
			job.call()
		if (Time.get_ticks_usec() - start) / 1000.0 >= BUDGET_MS:
			break
	if _jobs.is_empty():
		set_process(false)
		drained.emit()
