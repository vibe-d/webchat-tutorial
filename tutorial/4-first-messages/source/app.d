import vibe.d;

final class WebChat {
	private {
		Room[string] m_rooms;
	}

	// GET /
	void get()
	{
		render!"index.dt";
	}

	// GET /room?id=...&name=...
	void getRoom(string id, string name)
	{
		auto messages = getOrCreateRoom(id).messages;
		render!("room.dt", id, name, messages);
	}

	// POST /room?id=...&message=...
	void postRoom(string id, string name, string message)
	{
		if (message.length)
			getOrCreateRoom(id).addMessage(name, message);
		redirect("room?id="~id.urlEncode~"&name="~name.urlEncode);
	}

	private Room getOrCreateRoom(string id)
	{
		if (auto pr = id in m_rooms) return *pr;
		return m_rooms[id] = new Room;
	}
}

final class Room {
	string[] messages;

	void addMessage(string name, string message)
	{
		this.messages ~= name ~ ": " ~ message;
	}
}

shared static this()
{
	// the router will match incoming HTTP requests to the proper routes
	auto router = new URLRouter;
	// registers each method of WebChat in the router
	router.registerWebInterface(new WebChat);
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
}
