# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Documentation generator for the nit language.
# Generate API documentation in HTML format from nit source code.

module doc_layout

# header of the html page
class DocHeader
	var menu: DocMenu = new DocMenu

	# return html header
	fun html: String do
		var buffer = new Buffer
		buffer.append("<header>")
		buffer.append(menu.html)
		buffer.append("</header>")
		return buffer.to_s
	end
end

# menu of the html page
class DocMenu
	var items = new Array[String]

	# return html menu
	fun html: String do
		var buffer = new Buffer
		buffer.append("<nav class='main'>")
		buffer.append("<ul>")
		for item in items do buffer.append(item)
		buffer.append("</ul>")
		buffer.append("</nav>")
		return buffer.to_s
	end
end

# footer of the html page
class DocFooter
	var text: String writable

	init do end

	init with_text(text: String) do
		self.text = text
	end

	# return html footer
	fun html: String do
		var buffer = new Buffer
		buffer.append("<footer>")
		buffer.append(text)
		buffer.append("</footer>")
		return buffer.to_s
	end
end

# sidebar of the html page (<div class='sidebar')>)
class DocSidebar
	var boxes = new Array[DocSidebox]

	# return html sidebar
	fun html: String do
		var buffer = new Buffer
		buffer.append("<div class='sidebar'>")
		for box in boxes do buffer.append(box.html)
		buffer.append("</div>")
		return buffer.to_s
	end
end

# sidebox of the html page (<nav class='something'><h3>foo</h3>)
class DocSidebox
	var title: nullable String writable
	var groups = new Array[DocSideboxGroup]
	var css_class: nullable String

	init(t: String) do
		self.title = t
	end

	fun set_css_class(c: String) do
		self.css_class = c
	end

	# return html sidebox
	fun html: String do
		var buffer = new Buffer
		buffer.append("<nav")
		if css_class != null then buffer.append(" class='{css_class}'")
		buffer.append(">")
		if title != null then buffer.append("<h3>{title}</h3>")
		for group in groups do buffer.append(group.html)
		buffer.append("</nav>")
		return buffer.to_s
	end
end

# sideboxgroup of the html page (<ul>)
class DocSideboxGroup
	var title: nullable String
	var elements = new Array[DocListElement]

	# return html sideboxgroup
	fun html: String do
		var buffer = new Buffer
		if title != null then buffer.append("<h4>{title}</h4>")
		buffer.append("<ul>")
		for element in elements do buffer.append(element.html)
		buffer.append("</ul>")
		return buffer.to_s
	end
end

# elements of the html page (<li>)
class DocListElement
	var css_classes = new Array[String]
	var text: String

	# return html element
	fun html: String do
		return "<li class='{css_classes.join(" ")}'>{text}</li>"
	end
end

# full element of the html page (<li><span><a>)
class DocListElementFull super DocListElement
	var spans = new Array[DocListElementSpan]
	var links = new Array[DocListElementLink]

	# return html full element
	redef fun html: String do
		var buffer = new Buffer
		if css_classes.is_empty then
			buffer.append("<li>")
		else
			buffer.append("<li class='{css_classes.join(" ")}'>")
		end
		if not spans.is_empty then
			for span in spans do buffer.append(span.html)
		end
		if links.is_empty then
				buffer.append(text)
		else
			for link in links do buffer.append(link.html)
		end
		buffer.append("</li>")
		return buffer.to_s
	end

end

# span of the html page (<span>)
class DocListElementSpan
	var text: String
	var css_title: nullable String

	init (t: String) do self.text = t
	# return html span

	fun set_css_title (s: String) do self.css_title = s

	fun html: String do
		return "<span title='{css_title}'>{text}</span>"
	end
end

# link of the html page (<a>)
class DocListElementLink
	var text: String
	var css_title: nullable String
	var css_href: nullable String

	init(t: String) do self.text = t

	fun set_css_title (s: String) do self.css_title = s

	fun set_css_href (s: String) do self.css_href = s

	# return the html link of an element
	fun html: String do
		var buffer = new Buffer
		buffer.append("<a")
		if css_title != null then buffer.append(" title='{css_title}'")
		if css_href != null then buffer.append(" href='{css_href}'")
		buffer.append(">{text}</a>")
		return buffer.to_s
	end
end
