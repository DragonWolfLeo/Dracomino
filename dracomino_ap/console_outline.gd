extends PanelContainer

@export var console:Control:
    set(value):
        if console == value: return
        # Clean up existing connections
        if console:
            if console.focus_entered.is_connected(show):
                console.focus_entered.disconnect(show)
            if console.focus_exited.is_connected(hide):
                console.focus_exited.disconnect(hide)

        if value:
            # Show when focused
            value.focus_entered.connect(show)
            value.focus_exited.connect(hide)
            visible = value.has_focus()
        else:
            # Hide if console is null
            hide()
            print("console_outline.gd warning: console is null")
        console = value