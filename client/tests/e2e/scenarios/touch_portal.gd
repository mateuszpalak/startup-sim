## Dev (not in run.py): screenshots of the job portal on a touch screen.
## Server: --no-save --allow-guests; client: --touch=phone --nick=X --autoconnect
## --scenario=touch_portal --shots=/dir [--auto-recruit=1]
extends "res://tests/e2e/scenario.gd"

var dir := ""


func shot(name: String) -> void:
	await wait(1.0)
	await RenderingServer.frame_post_draw
	main.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	log_step("shot " + name)


func run() -> void:
	dir = str(main.args.get("shots", "/tmp"))
	var p = main.portal
	await wait(3.0)
	p._open_window("browser")
	await shot("portal_browser")
	if not p.offers.is_empty():
		p._browser_view = "form"
		p._form_offer = p.offers.keys()[0]
		p._render("browser")
		await shot("portal_form")
	p._show_question({"index": 1, "total": 5, "attempt": 1, "text": "Co robisz, gdy produkcja leży w piątek o 16:55?",
		"options": ["Naprawiam, piątek nie ucieknie", "Piszę na kanale #ogólny „ktoś coś?”", "Wyłączam komputer i idę na pociąg", "Robię rollback i dokumentuję"]}, "dev")
	await shot("portal_interview")
	main.net.packet_received.disconnect(main._on_packet)  # the real clock would hide it
	main.portal_layer.visible = false
	main.day_screen.on_clock({"day": 1, "minute": 7 * 60 + 30, "place": Protocol.PLACE_COMMUTING, "arrive": Protocol.NO_TIME, "mode": 0, "pay": 0, "money": 5000, "night": false, "weather": 0, "depart": 0, "pay_minutes": 0})
	await shot("commute")
	done()
