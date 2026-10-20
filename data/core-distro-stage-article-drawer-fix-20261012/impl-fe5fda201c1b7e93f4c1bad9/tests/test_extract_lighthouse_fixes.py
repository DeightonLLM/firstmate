#!/usr/bin/env python3
"""Unit tests for route-fragment Lighthouse fixes; local strings only."""
import importlib.util
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "extract_route_content", ROOT / "tools" / "extract-route-content.py"
)
EXTRACTOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXTRACTOR)


class LighthouseMarkupFixesTest(unittest.TestCase):
    def test_button_inside_link_becomes_one_styled_link(self):
        source = (
            '<a href="/contact/"><button class="btn-primary w-full" '
            'type="button" disabled="" aria-disabled="true">Request Quote</button></a>'
        )
        result = EXTRACTOR.flatten_anchor_buttons(source)
        self.assertIn('<a href="/contact/" class="btn-primary w-full">Request Quote</a>', result)
        self.assertNotIn("<button", result)

    def test_product_media_and_empty_links_are_local_or_removed(self):
        source = (
            '<a href="/products/glass-vials/"></a>'
            '<video poster="/images/automation-machine-v2.webp">'
            '<source src="/automation-machine-video_93d11a5b.mp4" type="video/mp4">'
            '</video>'
        )
        result = EXTRACTOR.sanitize_lighthouse_markup(source, "products")
        self.assertNotIn('<a href="/products/glass-vials/"></a>', result)
        self.assertIn('poster="__CD_STAGE_ASSET__/automation-machine-v2.webp"', result)
        self.assertNotIn("automation-machine-video_93d11a5b.mp4", result)

    def test_route_heading_and_contrast_fixes_preserve_words(self):
        contact = (
            '<h1>Contact</h1><h3>What to Expect</h3>'
            '<span style="color:oklch(0.55 0.04 148)">Headquarters</span>'
        )
        result = EXTRACTOR.sanitize_lighthouse_markup(contact, "contact")
        self.assertIn("<h2>What to Expect</h2>", result)
        self.assertIn("Headquarters", result)
        self.assertIn("color:oklch(0.45 0.04 148)", result)

        blog = EXTRACTOR.sanitize_lighthouse_markup(
            '<h1>Industry Insights</h1><h3>Stay Informed</h3>'
            '<p style="color:oklch(0.50 0.04 148)">No spam.</p>',
            "blog",
        )
        self.assertIn("<h2>Stay Informed</h2>", blog)
        self.assertIn("color:oklch(0.70 0.04 148)", blog)

    def test_pdf_neutralization_replaces_the_complete_link(self):
        source = '<a href="/files/catalog.pdf">Download catalogue</a>'
        result, count = EXTRACTOR.neutralize_document_downloads(source)
        self.assertEqual(1, count)
        self.assertIn('>Download catalogue</span>', result)
        self.assertNotIn('</a>', result)

    def test_textarea_is_emitted_once_and_source_text_is_not_exposed(self):
        parser = EXTRACTOR.ContentExtractor()
        parser.feed(
            '<header></header><main><form><textarea placeholder="Internal note">'
            'Do not expose this source text</textarea></form></main><footer></footer>'
        )
        parser.close()
        result = ''.join(parser.parts)
        self.assertEqual(1, len(re.findall(r'<textarea\b', result, re.I)))
        self.assertEqual(1, len(re.findall(r'</textarea\s*>', result, re.I)))
        self.assertNotIn('Do not expose this source text', result)

    def test_verifier_rejects_unbalanced_tags(self):
        result = EXTRACTOR.verify('resources', '<h1>Resources</h1><span>Download</a>')
        self.assertTrue(any('unbalanced' in problem for problem in result))

    def test_extract_pipeline_emits_balanced_inert_markup(self):
        source = (
            '<header></header><main><h1>Catalogue</h1>'
            '<nav aria-label="Breadcrumb"><a href="/">Home</a></nav>'
            '<a href="/files/catalog.pdf">Download catalogue</a>'
            '<form><label for="notes">Notes</label>'
            '<textarea id="notes" placeholder="Notes">Do not expose</textarea>'
            '<button>Submit</button></form>'
            '<video poster="/images/automation-machine-v2.webp">'
            '<source src="/missing-machine.mp4" type="video/mp4"></video>'
            '</main><footer></footer>'
        )
        with tempfile.TemporaryDirectory() as directory:
            capture = Path(directory) / 'route.html'
            capture.write_text(source, encoding='utf-8')
            output = EXTRACTOR.extract(str(capture), 'products')
        self.assertEqual([], EXTRACTOR.verify('products', output))
        self.assertIn('<span class="cd-inert-download"', output)
        self.assertIn('</span>', output)
        self.assertIn('<nav aria-label="Breadcrumb">', output)
        self.assertEqual(1, len(re.findall(r'<textarea\b', output, re.I)))
        self.assertEqual(1, len(re.findall(r'</textarea\s*>', output, re.I)))
        self.assertNotIn('Do not expose', output)
        self.assertNotIn('/missing-machine.mp4', output)

    def test_verifier_rejects_nested_and_empty_links(self):
        self.assertTrue(EXTRACTOR.verify("contact", '<h1>Contact</h1><a href="/x"><button>Go</button></a>'))
        self.assertTrue(EXTRACTOR.verify("contact", '<h1>Contact</h1><a href="/x"></a>'))


if __name__ == "__main__":
    unittest.main(verbosity=2)
