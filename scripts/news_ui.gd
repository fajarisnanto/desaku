extends CanvasLayer
var village: Node
var feed: Node
var shade: ColorRect
var list: ItemList
var detail: RichTextLabel
var status: Label
var toggle: Button
var open_link: Button
var visible_items: Array = []
var selected_url := ""
func setup(owner_village: Node, news_feed: Node) -> void:
	village=owner_village
	feed=news_feed
	layer=13
	village.settings_ui.button("News desk  [N]",Vector2(1280,276),Vector2(230,42),village.settings_ui,open)
	shade=ColorRect.new()
	shade.color=Color(0.015,0.04,0.06,0.96)
	shade.size=Vector2(1536,1024)
	add_child(shade)
	shade.hide()
	var panel=village.panel(Vector2(65,60),Vector2(1406,904),shade)
	village.label("WORLD IT NEWS / VILLAGE READING ROOM",Vector2(28,24),27,panel)
	village.label("Dated headlines · Security, exploited CVEs and AI research · Last 14 days",Vector2(28,66),17,panel)
	village.settings_ui.button("Back",Vector2(1240,24),Vector2(130,40),panel,close)
	toggle=village.settings_ui.button("",Vector2(28,110),Vector2(270,42),panel,func():feed.set_enabled(not feed.enabled))
	village.settings_ui.button("Refresh feeds",Vector2(315,110),Vector2(200,42),panel,func():feed.refresh())
	status=village.label("",Vector2(28,170),14,panel)
	list=ItemList.new()
	list.position=Vector2(28,280)
	list.size=Vector2(760,580)
	list.add_theme_font_size_override("font_size",17)
	list.fixed_column_width=730
	list.max_text_lines=3
	panel.add_child(list)
	list.item_selected.connect(show_item)
	detail=RichTextLabel.new()
	detail.position=Vector2(815,280)
	detail.size=Vector2(560,475)
	detail.bbcode_enabled=false
	detail.add_theme_font_size_override("normal_font_size",19)
	panel.add_child(detail)
	open_link=village.settings_ui.button("Read original source",Vector2(815,790),Vector2(300,44),panel,func():
		if not selected_url.is_empty():OS.shell_open(selected_url)
	)
	feed.changed.connect(refresh)
	refresh()
func open() -> void:
	village.office_ui.close()
	village.settings_ui.shade.hide()
	village.settings_ui.human_panel.hide()
	village.gallery.hide()
	shade.show()
	refresh()
func close() -> void:
	shade.hide()
func refresh() -> void:
	if list == null:return
	toggle.text="News enabled · click to disable" if feed.enabled else "News disabled · click to enable"
	status.text="Public feeds refresh every 30 minutes. News is cached locally; no village dialogue is sent to news sites.\n"
	for source in feed.SOURCES:
		status.text+=str(source.name)+": "+str(feed.reports.get(source.name,"Not checked this session"))+"\n"
	list.clear()
	visible_items=feed.stories.duplicate(true)
	for item in visible_items:
		list.add_item(str(item.source)+" · "+Time.get_datetime_string_from_unix_time(int(item.published)).left(10)+"\n"+str(item.title))
	selected_url=""
	open_link.disabled=true
	detail.text="Select a headline to inspect its source and date.\n\nResidents occasionally discuss these stories in their own voices. Creative considers AI and design; Research considers evidence; Operation considers impact; Maintenance considers security and upkeep.\n\nHeadlines are limited evidence, not full article summaries. These feeds provide international coverage, not an exhaustive worldwide news service."
	if not feed.current_story.is_empty():
		detail.text+="\n\nMost recent conversation source:\n"+str(feed.current_story.source)+" — "+str(feed.current_story.title)
	if visible_items.is_empty():detail.text="No dated recent headlines are available yet. Residents will continue ordinary small talk and will not be given invented news."
func show_item(index: int) -> void:
	if index<0 or index>=visible_items.size():return
	var item: Dictionary=visible_items[index]
	selected_url=item.url
	open_link.disabled=false
	detail.text=str(item.title)+"\n\nPublisher: "+str(item.source)+"\nCategory: "+str(item.topic)+"\n"+str(item.date_label)+": "+Time.get_datetime_string_from_unix_time(int(item.published)).replace("T"," ")+" UTC\nFetched: "+Time.get_datetime_string_from_unix_time(int(item.fetched)).replace("T"," ")+" UTC\n\n"+selected_url+"\n\nOnly headline metadata is available to the residents. Open the original for affected versions, severity, remediation and full context."
