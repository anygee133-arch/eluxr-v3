from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font('Helvetica', 'B', 10)
        self.set_text_color(150, 150, 150)
        self.cell(0, 8, 'ELUXR v3 - Product Overview', align='R')
        self.ln(12)

    def footer(self):
        self.set_y(-15)
        self.set_font('Helvetica', '', 8)
        self.set_text_color(150, 150, 150)
        self.cell(0, 10, f'Page {self.page_no()}/{{nb}}', align='C')

    def section_title(self, title):
        self.set_font('Helvetica', 'B', 18)
        self.set_text_color(15, 23, 41)
        self.cell(0, 12, title)
        self.ln(14)

    def sub_title(self, title):
        self.set_font('Helvetica', 'B', 13)
        self.set_text_color(30, 40, 60)
        self.cell(0, 10, title)
        self.ln(11)

    def sub_sub_title(self, title):
        self.set_font('Helvetica', 'B', 11)
        self.set_text_color(50, 60, 80)
        self.cell(0, 8, title)
        self.ln(9)

    def body_text(self, text):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.5, text)
        self.ln(3)

    def bullet(self, text, indent=10):
        self.set_font('Helvetica', '', 10)
        self.set_text_color(30, 30, 30)
        x = self.get_x()
        self.set_x(x + indent)
        self.cell(5, 5.5, '-')
        self.multi_cell(0, 5.5, text)
        self.ln(1)

    def bold_bullet(self, bold_part, rest, indent=10):
        x = self.get_x()
        self.set_x(x + indent)
        self.set_font('Helvetica', '', 10)
        self.set_text_color(30, 30, 30)
        self.cell(5, 5.5, '-')
        self.set_font('Helvetica', 'B', 10)
        self.write(5.5, bold_part)
        self.set_font('Helvetica', '', 10)
        self.write(5.5, rest)
        self.ln(6.5)

    def code_block(self, text):
        self.set_font('Courier', '', 9)
        self.set_text_color(60, 60, 60)
        self.set_fill_color(245, 245, 245)
        self.multi_cell(0, 5, text, fill=True)
        self.ln(3)

    def divider(self):
        self.set_draw_color(200, 200, 200)
        y = self.get_y()
        self.line(10, y, 200, y)
        self.ln(6)

    def table_row(self, cols, widths, bold=False):
        self.set_font('Helvetica', 'B' if bold else '', 9)
        self.set_text_color(30, 30, 30)
        h = 7
        for i, col in enumerate(cols):
            self.cell(widths[i], h, col, border=1)
        self.ln(h)

pdf = PDF()
pdf.alias_nb_pages()
pdf.set_auto_page_break(auto=True, margin=20)
pdf.add_page()

# Title page
pdf.ln(30)
pdf.set_font('Helvetica', 'B', 32)
pdf.set_text_color(15, 23, 41)
pdf.cell(0, 15, 'ELUXR v3', align='C')
pdf.ln(18)
pdf.set_font('Helvetica', '', 16)
pdf.set_text_color(80, 80, 80)
pdf.cell(0, 10, 'Product Overview & Architecture', align='C')
pdf.ln(12)
pdf.set_font('Helvetica', '', 11)
pdf.cell(0, 8, 'How the Magic Content Engine works, step by step', align='C')
pdf.ln(25)
pdf.set_font('Helvetica', '', 10)
pdf.set_text_color(120, 120, 120)
pdf.cell(0, 8, 'March 2026', align='C')

# Page 2: The Concept
pdf.add_page()
pdf.section_title('The Concept')
pdf.body_text('A business enters their website URL. The system scrapes their site, analyzes their brand, generates a full 30-day social media content calendar with AI-written posts for 6 platforms (Instagram, Facebook, YouTube, TikTok, LinkedIn, X), AI-generated images, and video scripts. Netflix-style weekly storytelling themes tie it all together.')
pdf.ln(5)

pdf.sub_title('Tech Stack')
pdf.bold_bullet('Frontend: ', 'Vanilla HTML/CSS/JS - single index.html (~7200 lines), no framework')
pdf.bold_bullet('Backend: ', 'n8n Cloud (flowbound.app.n8n.cloud) - 16+ workflows')
pdf.bold_bullet('Database: ', 'Supabase (PostgreSQL + Auth + Realtime + Row-Level Security)')
pdf.bold_bullet('Hosting: ', 'Vercel (static site deployment)')
pdf.bold_bullet('AI Models: ', 'Claude Sonnet 4 (content/topics/themes/ICP), GPT-4o (image analysis), GPT-4.1-mini (image prompts), Perplexity Sonar (research), KIE Nano Banana Pro (image generation)')
pdf.ln(5)

pdf.sub_title('Authentication')
pdf.body_text('Supabase email/password login produces a JWT token. Every API call to n8n uses authenticatedFetch() which sends the JWT in the Authorization header. An Auth Validator sub-workflow validates the JWT on every request. Supabase Row-Level Security ensures users only see their own data.')

pdf.divider()

# Step 1
pdf.section_title('Step 1: Define Your Business Profile')

pdf.sub_title('What the user does')
pdf.bullet('Enters their website URL, selects industry, content month, target platforms, language')
pdf.bullet('Picks a storytelling theme (Luxury Intrigue, Emotional Journey, Authority & Educator, or Cinematic Series)')
pdf.bullet('Optionally sets brand voice parameters')
pdf.bullet('Clicks "Analyze My Business"')

pdf.sub_title('What happens behind the scenes')

pdf.sub_sub_title('1. Pipeline Orchestrator (WF 14)')
pdf.body_text('Frontend sends the URL to the Pipeline Orchestrator webhook, which coordinates the entire analysis sequentially.')

pdf.sub_sub_title('2. ICP Analyzer (WF 01 - 48 nodes)')
pdf.bold_bullet('Jina AI ', 'scrapes the homepage + 3 pages of product listings (paginated)')
pdf.bold_bullet('Claude Sonnet 4 ', 'extracts products from the scraped HTML - names, descriptions, prices, categories, image URLs')
pdf.bold_bullet('Perplexity Sonar (3 calls): ', 'Research 1: Industry trends & competitive landscape. Research 2: Target audience demographics & psychographics. Research 3: Content gaps & opportunities.')
pdf.bold_bullet('Claude Sonnet 4 ', 'synthesizes all research into a full ICP: summary, target audience (age, gender, income, job titles), pain points, values, content pillars, recommended hashtags per platform')
pdf.bullet('Products cleaned, deduplicated, inserted into Supabase "products" table')
pdf.bullet('ICP inserted into Supabase "icps" table')
pdf.bullet('For JS-heavy sites (Tiffany, Cartier) where Jina cannot scrape: Perplexity fallback discovers products and searches for images')

pdf.sub_sub_title('3. Theme Generator (WF 02)')
pdf.bold_bullet('Claude Sonnet 4 ', 'generates a Netflix-model show concept:')
pdf.bullet('Show name (e.g., "The Artisan\'s Vault Series")', indent=20)
pdf.bullet('4 weekly "seasons" with progressive arcs (intro, deepen, challenge, celebrate)', indent=20)
pdf.bullet('Each season has a theme name, description, hook, and 7 daily content types with product assignments', indent=20)
pdf.bullet('Themes inserted into Supabase "themes" table (4 rows, one per week)')

pdf.sub_title('What gets displayed')
pdf.bullet('Business profile card with ICP summary, target audience demographics, pain points, content opportunities')
pdf.bullet('Recommended hashtags (deduplicated across platforms)')
pdf.bullet('All products listed in Step 2 with thumbnails, descriptions, product URLs')

pdf.sub_sub_title('Database tables touched')
pdf.body_text('campaigns, products, icps, themes')

pdf.divider()

# Step 2
pdf.section_title('Step 2: Your Products')

pdf.sub_title('What the user does')
pdf.bullet('Reviews scraped products (shown with thumbnail images, names, descriptions, categories)')
pdf.bullet('Can click product images to see full size')
pdf.bullet('Can rename products, delete unwanted ones, add custom products')
pdf.bullet('Products are grouped with drag handles for reordering')

pdf.sub_title('What happens behind the scenes')
pdf.body_text('Products were already loaded during Step 1. Frontend reads from Supabase "products" table filtered by user_id. Product edits/deletions update the table directly via Supabase client. No n8n workflows involved - purely frontend to Supabase.')

pdf.sub_title('What gets displayed')
pdf.bullet('Numbered list of all products (e.g., 21 for sparkcreations.com)')
pdf.bullet('Each has: thumbnail image, editable name, product URL link, description, category')
pdf.bullet('Collapsible section with product count badge')

pdf.divider()

# Step 3
pdf.section_title('Step 3: Weekly Topics')

pdf.sub_title('What the user does')
pdf.bullet('Clicks "Generate Week 1 Topics" (or Week 2, 3, 4)')
pdf.bullet('Reviews 7 generated topic cards (one per day: Mon-Sun)')
pdf.bullet('Each card shows: day name, storytelling theme, topic title, content angle, assigned product with image')
pdf.bullet('Can approve individual topics, regenerate single topics, or "Approve All & Generate Content"')

pdf.sub_title('What happens behind the scenes')

pdf.sub_sub_title('Topic Generation (WF 15)')
pdf.bullet('Frontend sends campaign_id, week_number, ordered product list')
pdf.bullet('WF 15 deletes existing topics for this campaign+week (clean slate)')
pdf.bullet('Builds prompt with 7-day storytelling framework, product assignments (rotated - excludes products used in prior weeks), and ICP context')
pdf.bold_bullet('Claude Sonnet 4 ', 'generates 7 topics: title, description, content_angle, product assignment, storytelling_theme')
pdf.bullet('Topics inserted into Supabase "weekly_topics" table (7 rows)')
pdf.bullet('Campaign current_week updated')

pdf.sub_sub_title('When user clicks "Approve All & Generate Content"')
pdf.bullet('All 7 topics get status "approved" in Supabase')
pdf.bullet('Frontend fires webhook to WF 04 Content Studio (see Step 4)')

pdf.sub_title('What gets displayed')
pdf.bullet('Week tabs (Week 1-4), unlocked progressively')
pdf.bullet('7 topic cards with: day badge, storytelling theme, topic title, description, content angle, product name + clickable thumbnail')
pdf.bullet('Approve/Regenerate buttons per topic')
pdf.bullet('"Content Generated" badge after Step 4 completes')

pdf.sub_sub_title('Database tables touched')
pdf.body_text('weekly_topics')

pdf.divider()

# Step 4
pdf.section_title('Step 4: Content Review')

pdf.sub_title('What the user does')
pdf.bullet('Sees day cards grouped by Week 1, Week 2 (collapsible headers with stats)')
pdf.bullet('Clicks a day card to open the day modal:')
pdf.bullet('Topic header with storytelling theme, topic title, content angle', indent=20)
pdf.bullet('Product image + name', indent=20)
pdf.bullet('Day Image section: Generate Image > Approve > Download', indent=20)
pdf.bullet('Day Video section: Generate Video (unlocked after image approved)', indent=20)
pdf.bullet('Platform Posts: 6 sections (Instagram, Facebook, YouTube, TikTok, LinkedIn, X) each with full post text, hashtags, Approve/Edit/Reject', indent=20)

pdf.sub_title('What happens behind the scenes')

pdf.sub_sub_title('1. Content Generation (WF 04 Content Studio)')
pdf.bullet('Triggered from Step 3 "Approve All & Generate Content"')
pdf.bullet('Reads theme, ICP, products, and approved weekly_topics from Supabase')
pdf.bullet('Deletes old pending_review content for this campaign (clean slate)')
pdf.body_text('Builds the megaPrompt - a massive prompt containing:')
pdf.bullet('7-day Viral Storytelling Framework (Curiosity > Craftsmanship > Meaning > Transformation > Surprise > Aspiration > Legacy)', indent=20)
pdf.bullet('Per-day assignments: product context, topic, content angle', indent=20)
pdf.bullet('Platform-specific rules (character limits, tone, format for each of 6 platforms)', indent=20)
pdf.bullet('Strict JSON output schema', indent=20)
pdf.bold_bullet('Claude Sonnet 4 ', 'generates ALL content in one API call (~4 minutes): 7 days x 6 platforms = 42 content items')
pdf.body_text('Each item has: platform post text, hashtags, first_comment (Instagram), CTA, video scripts (YouTube/TikTok with scenes, timing, visuals, narration), image_prompt.')
pdf.bullet('42 items batch-inserted into Supabase "content_items" table')

pdf.sub_sub_title('2. Image Generation (per day, user-triggered)')
pdf.bullet('User clicks "Generate Image" on a day card')
pdf.bullet('Frontend sends content item to Image Generator workflow')
pdf.bold_bullet('GPT-4o ', 'vision-analyzes the product image (19 fields: stone type, orientation, material finish, colors, etc.)')
pdf.bold_bullet('GPT-4.1-mini ', 'acts as photorealistic prompt engineer - writes a detailed image prompt with physical form rules (rigid/flexible/articulated jewelry), body placement, lighting, composition')
pdf.bold_bullet('KIE Nano Banana Pro ', 'generates the image (4:5 ratio)')
pdf.bullet('Image URL saved to content_items.image_url in Supabase')

pdf.sub_sub_title('3. Video Generation (per day, after image approved)')
pdf.bullet('User clicks "Generate Video" (unlocked after image is approved)')
pdf.bullet('Uses the approved image + video script from the content item')
pdf.bullet('Video URL saved to content_items.video_url')

pdf.sub_title('What gets displayed')
pdf.bullet('Grouped day cards (Week 1, Week 2 headers with post count and approved count)')
pdf.bullet('Day modal: topic header, product image, image gen/approve/download, video gen, 6 platform post cards with full formatted text, hashtags, approve/edit/reject per post')

pdf.sub_sub_title('Database tables touched')
pdf.body_text('content_items')

pdf.divider()

# Step 5
pdf.section_title('Step 5: Your Content Calendar')

pdf.sub_title('What the user does')
pdf.bullet('Sees a weekly calendar view (Mon-Sun)')
pdf.bullet('Navigates weeks with Prev/Next buttons')
pdf.bullet('Each day card shows: platform badges (IG, FB, YT, TT, LI, X) color-coded by status, content preview, generated image thumbnail')
pdf.bullet('Clicks a day to see full content in a modal')
pdf.bullet('Export CSV, Clear Pending, Refresh buttons')
pdf.bullet('"Reset & Start Fresh" at the bottom to wipe everything and start over')

pdf.sub_title('What happens behind the scenes')
pdf.body_text('Frontend calls fetchCalendarData() which queries Supabase content_items filtered by campaign_id. Groups content by scheduled_date and renders a 7-day grid. Content dates start from today (not day 1 of the month). The schedule modal shows the same data as Step 4 but in calendar context, with formatted video scripts (not raw JSON).')

pdf.sub_title('What gets displayed')
pdf.bullet('Week navigation with date range (e.g., "Mar 24 - Mar 30")')
pdf.bullet('7 day cards with: day name, date, platform status badges, image thumbnail, content preview')
pdf.bullet('Stats bar: Total Posts, Pending, Approved, Videos')
pdf.bullet('Reset & Start Fresh button')

pdf.sub_sub_title('Database tables touched')
pdf.body_text('Reads content_items (same as Step 4)')

pdf.divider()

# Data flow
pdf.section_title('Data Flow Summary')
pdf.code_block(
    'User enters URL\n'
    '  |\n'
    '  v\n'
    'WF 14 Orchestrator\n'
    '  |\n'
    '  v\n'
    'WF 01: Jina scrape > Perplexity research x3 > Claude ICP synthesis\n'
    '        > products + icp saved to Supabase\n'
    '  |\n'
    '  v\n'
    'WF 02: Claude theme generation > 4 weekly themes saved\n'
    '  |\n'
    '  v\n'
    'User clicks "Generate Topics"\n'
    '  |\n'
    '  v\n'
    'WF 15: Claude topic generation > 7 topics saved\n'
    '  |\n'
    '  v\n'
    'User clicks "Approve All & Generate Content"\n'
    '  |\n'
    '  v\n'
    'WF 04: Claude content generation > 42 content items saved\n'
    '  |\n'
    '  v\n'
    'User clicks "Generate Image" per day\n'
    '  |\n'
    '  v\n'
    'Image Gen: GPT-4o analysis > GPT-4.1-mini prompt > KIE image\n'
    '           > image_url saved\n'
    '  |\n'
    '  v\n'
    'User clicks "Generate Video" per day\n'
    '  |\n'
    '  v\n'
    'WF 13: Video generation > video_url saved'
)

pdf.ln(5)

# Database schema
pdf.section_title('Database Schema (Key Tables)')

w = [35, 55, 100]
pdf.table_row(['Table', 'Key Columns', 'Purpose'], w, bold=True)
pdf.table_row(['campaigns', 'id, user_id, month, show_name, current_week', 'One per user per month'], w)
pdf.table_row(['products', 'id, user_id, name, description, image_url', 'Scraped products'], w)
pdf.table_row(['icps', 'id, user_id, icp_summary, content_pillars', 'Business profile analysis'], w)
pdf.table_row(['themes', 'id, campaign_id, week_number, theme_name', '4 weekly show themes'], w)
pdf.table_row(['weekly_topics', 'id, campaign_id, week/day_number, topic', '7 topics per week'], w)
pdf.table_row(['content_items', 'id, campaign_id, platform, content, date', '42 posts per week (7x6)'], w)

pdf.ln(8)

# Workflow reference
pdf.section_title('Workflow Reference')
w2 = [60, 55, 75]
pdf.table_row(['Workflow', 'ID', 'Purpose'], w2, bold=True)
pdf.table_row(['01-ICP-Analyzer', 'Bin0AjccOtr2etgH', 'Scrape, research, extract products + ICP'], w2)
pdf.table_row(['02-Theme-Generator', 'hQeqQ0r6Ahop3YOI', 'Netflix show themes (4 weeks)'], w2)
pdf.table_row(['04-Content-Studio', 'TreszUaJqlykCrMi', 'Generate 42 platform posts'], w2)
pdf.table_row(['14-Pipeline-Orchestrator', 'Tjtmepkq6WnxQFtU', 'Coordinates Step 1 pipeline'], w2)
pdf.table_row(['15-Generate-Topics', 'qTDGBLtfBqyb1Vm1', 'Generate 7 daily topics'], w2)
pdf.table_row(['16-Regenerate-Topic', 'jTb1lkySSEcmlBOE', 'Regenerate single topic'], w2)
pdf.table_row(['Image Generator', 'Yh5DEtB1lR9lkbzo', 'Product image > AI image'], w2)
pdf.table_row(['13-Video-Creator', 'QobjIFK54hxiKfVi', 'Image + script > video'], w2)
pdf.table_row(['Auth Validator', 'S4QtfIKpvhW4mQYG', 'JWT validation sub-workflow'], w2)

pdf.output('/Users/andrewgershan/Projects/eluxr-v3/docs/ELUXR-Product-Overview.pdf')
print('PDF generated successfully')
