class DebugEventData {
	final String message;

	DebugEventData({
		this.message = ''
	});

	@override
	String toString() {
		return this.message;
	}
}