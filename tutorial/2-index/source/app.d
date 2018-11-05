import vibe.d;

final class WebChat {
	// GET /
	void get()
	{
		render!"index.dt";
	}
}

void main()
{
	// the router will match incoming HTTP requests to the proper routes
	auto router = new URLRouter;
	// registers each method of WebChat in the router
	router.registerWebInterface(new WebChat);
	// match incoming requests to files in the public/ folder
	router.get("*", serveStaticFiles("public/"));

	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	// for production installations, the error stack trace option should
	// stay disabled, because it can leak internal address information to
	// an attacker. However, we'll let keep it enabled during development
	// as a convenient debugging facility.
	//settings.options &= ~HTTPServerOption.errorStackTraces;
	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");

	runApplication();
}
