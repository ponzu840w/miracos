SRC = index.adoc
PDF_OUT = pdf_out
HTML_OUT = html_out
THEME = res/theme.yml

ADOC_HTML = bundle exec asciidoctor
ADOC_PDF  = bundle exec asciidoctor-pdf

.PHONY: all html pdf clean

all: html pdf

html:
	@echo "Building HTML to $(HTML_OUT)..."
	@mkdir -p $(HTML_OUT)
	$(ADOC_HTML) \
		-r asciidoctor-multipage \
		-r asciidoctor-diagram \
		-b multipage_html5 \
		-a toc=left \
		-a docinfo=shared \
		-D $(HTML_OUT) \
		$(SRC)
	@echo "Done."

pdf:
	@echo "Building PDF to $(PDF_OUT)..."
	@mkdir -p $(PDF_OUT)
	$(ADOC_PDF) \
		-r asciidoctor-pdf-cjk \
		-r asciidoctor-diagram \
		-a pdf-theme=$(THEME) \
		-a imagesoutdir=. \
		-D $(PDF_OUT) \
		$(SRC)
	@echo "Done."

clean:
	rm -rf $(HTML_OUT) $(PDF_OUT) *.png *.svg .asciidoctor
