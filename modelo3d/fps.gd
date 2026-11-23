# --fps N: cuántos cuadros por segundo da el juego desde donde está la cámara, para comparar antes y después de un
# cambio. Sin sincronía vertical ni tope, espera CALENTAR segundos (que se compilen los sombreadores y se asienten las
# sombras), cuenta los cuadros de N segundos, imprime una línea y sale:
#   fps.gd: 61.3 cuadros por segundo (16.31 ms, peor 24.0 ms; GPU 9.80 ms, CPU de render 2.10 ms) en 1600x1000, 812 dibujos, 3786782 primitivas
# --render E dibuja la escena a E² veces los píxeles (cuánto margen queda bajo el tope de la pantalla). Es el único
# arnés: reemplaza al de calles.gd (--fps, 3 s) y al de plaza.gd (PLAZA_FPS=1, 6 s tras 4), que sigue sirviendo con un
# aviso. mundo.gd armar() lo agrega después de los modelos.
extends Node

const Args := preload("res://args.gd")
const CALENTAR := 4.0

var segundos := 0.0  # los de pedido(): mundo.gd los pone


# los segundos que pide la línea de comandos (0: no se mide)
static func pedido() -> float:
	if Args.has("--fps"):
		return Args.num("--fps", 5.0, 0.5, 600.0)
	if OS.has_environment("PLAZA_FPS"):
		push_warning("fps.gd: PLAZA_FPS=1 ahora es --fps 6")
		return 6.0
	return 0.0


func _ready() -> void:
	medir.call_deferred(segundos)


func medir(n: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if Args.has("--escala") and not Args.has("--vp"):
		push_warning("fps.gd: la escala del render ahora es --render (--escala es la de la plaza en --vp)")
	if Args.has("--render"):
		get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		get_viewport().scaling_3d_scale = Args.num("--render", 1.0, 0.25, 2.0)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await get_tree().create_timer(CALENTAR).timeout
	var gpu := 0.0
	var cpu := 0.0
	var peor := 0.0
	var k := 0
	var t0 := Time.get_ticks_usec()
	var t := t0
	while Time.get_ticks_usec() - t0 < n * 1e6:
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		peor = maxf(peor, (ahora - t) / 1000.0)
		t = ahora
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		k += 1
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / k
	print("fps.gd: %.1f cuadros por segundo (%.2f ms, peor %.1f ms; GPU %.2f ms, CPU de render %.2f ms) en %dx%d, %d dibujos, %d primitivas" % [
		1000.0 / ms, ms, peor, gpu / k, cpu / k, get_viewport().size.x, get_viewport().size.y,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	get_tree().quit()
