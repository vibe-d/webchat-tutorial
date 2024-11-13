import vibe.d;

final class WebChat {
	private {
		RedisDatabase m_db;
		RedisSubscriber m_subscriber;
		Room[string] m_rooms;
	}

	this()
	{
		// connect to Redis for storing our message history
		m_db = connectRedis("127.0.0.1").getDatabase(0);

		// setup a PubSub subscriber to listen for new messages
		m_subscriber = RedisSubscriber(m_db.client);
		m_subscriber.subscribe("webchat");
		m_subscriber.listen((channel, message) {
			if (auto pr = message in m_rooms)
				pr.messageEvent.emit();
		});
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

	// GET /ws?room=...,
	void getWS(string room, string name, scope WebSocket socket)
	{
		auto r = getOrCreateRoom(room);

		// watch for new messages in the history and send them
		// to the client
		runTask(delegate () nothrow{
			// keep track of the last message that got already sent to the client
			// we assume that we sent all message so far
			try
			{
				auto next_message = r.messages.length;
				// send new messages as they come in
				while (socket.connected) {
					while (next_message < r.messages.length)
						socket.send(r.messages[next_message++]);
					r.waitForMessage(next_message);
				}
			}
			catch (Exception e){
				logInfo("Websocket crashed: %s", e);
			}
		});

		// receive messages from the client and add it to the history
		while (socket.waitForData) {
			auto message = socket.receiveText();
			if (message.length) r.addMessage(name, message);
		}
	}

	private Room getOrCreateRoom(string id)
	{
		if (auto pr = id in m_rooms) return *pr;
		return m_rooms[id] = new Room(m_db, id);
	}
}

final class Room {
	RedisDatabase db;
	string id;
	RedisList!string messages;
	LocalManualEvent messageEvent;

	this(RedisDatabase db, string id)
	{
		this.db = db;
		this.id = id;
		this.messages = db.getAsList!string("webchat_"~id);
		this.messageEvent = createManualEvent();
	}

	void addMessage(string name, string message)
	{
		this.messages.insertBack(name ~ ": " ~ message);
		this.db.publish("webchat", id);
	}

	void waitForMessage(long next_message)
	{
		while (messages.length <= next_message)
			messageEvent.wait();
	}
}

void main()
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

	runApplication();
}
