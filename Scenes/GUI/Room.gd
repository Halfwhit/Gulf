extends Panel

func _input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			get_parent().send_message()

func send_message():
	var message = ChatInput.text
	chat_input.text = ""
	var id = get_tree().get_network_unique_id()
	rpc("receive_message", id, message)
	print("Sending message")