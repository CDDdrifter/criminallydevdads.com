-- Seed DRAFT legal / policy CMS pages so the owner has starter scaffolding to
-- edit under Admin → Pages. Pages are created unpublished (published = false)
-- and hidden from nav; publish each after editing the real text.
--
-- NOT LEGAL ADVICE. These are templates with placeholders ([Business name],
-- [contact email], [jurisdiction]) — review with a professional before relying
-- on them. Re-running is safe: ON CONFLICT (slug) DO NOTHING preserves edits.

DO $$
DECLARE
  disclaimer_block jsonb := jsonb_build_object(
    'id', gen_random_uuid()::text,
    'kind', 'callout',
    'tone', 'warning',
    'icon', '⚠️',
    'title', 'Template — review before publishing',
    'body', 'This is starter text generated for you. Replace placeholders and have it reviewed by a qualified professional. It is not legal advice.'
  );
BEGIN
  INSERT INTO public.site_pages (slug, title, body, sections, show_in_nav, published, sort_order, page_mode)
  VALUES
    (
      'terms',
      'Terms of Service',
      'Replace this with your Terms of Service.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'Terms of Service'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          'By accessing [Business name] (the "Site") or purchasing products or services, you agree to these Terms. If you do not agree, do not use the Site. We may update these Terms at any time; continued use means acceptance. Eligibility: you must be the age of majority in your [jurisdiction]. Accounts: you are responsible for activity under your account. Purchases are governed by our Refund Policy. We provide the Site "as is" and disclaim warranties to the fullest extent permitted by law. Our liability is limited to the amount you paid in the prior 12 months. Contact: [contact email].')
      ),
      false, false, 900, 'blocks'
    ),
    (
      'privacy',
      'Privacy Policy',
      'Replace this with your Privacy Policy.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'Privacy Policy'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          'This Policy explains how [Business name] collects and uses information. We collect: account details (email), order/payment metadata (processed by Stripe — we do not store card numbers), mailing-list opt-ins, and basic analytics. We use this to provide services, process orders, send updates you opt into, and improve the Site. We share data only with processors (e.g. Stripe, our hosting/email providers) as needed. We retain data as long as necessary or as law requires. You may request access or deletion at [contact email]. We use cookies — see our Cookie Policy.')
      ),
      false, false, 901, 'blocks'
    ),
    (
      'refund',
      'Refund Policy',
      'Replace this with your Refund Policy.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'Refund Policy'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'callout', 'tone', 'danger', 'icon', '🚫',
          'title', 'All sales are final',
          'body', 'Digital products (downloads, keys, game builds) and commissioned/custom work are non-refundable once delivered or once work has begun. By completing checkout you waive any right of withdrawal for digital goods supplied immediately.'),
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          'Physical products may be returned only if they arrive damaged or defective — contact [contact email] within 14 days with photos. Chargebacks filed without first contacting us may result in account suspension. Where local law grants non-waivable refund rights, those rights still apply.')
      ),
      false, false, 902, 'blocks'
    ),
    (
      'cookie',
      'Cookie Policy',
      'Replace this with your Cookie Policy.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'Cookie Policy'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          '[Business name] uses essential cookies/local storage to run the Site (sessions, preferences, cookie-consent state). If analytics are enabled, we may set analytics cookies to understand usage. You can clear cookies in your browser at any time; disabling essential cookies may break parts of the Site.')
      ),
      false, false, 903, 'blocks'
    ),
    (
      'dmca',
      'DMCA / Copyright',
      'Replace this with your copyright / DMCA policy.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'DMCA / Copyright Policy'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          'We respect intellectual property. To report infringing content, email [contact email] with: identification of the work, the URL of the material, your contact info, a good-faith statement, and a statement under penalty of perjury that you are authorized to act. We will respond and may remove content. Repeat infringers may be terminated.')
      ),
      false, false, 904, 'blocks'
    ),
    (
      'disclaimer',
      'Disclaimer',
      'Replace this with your disclaimer.',
      jsonb_build_array(
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'heading', 'title', 'Disclaimer'),
        disclaimer_block,
        jsonb_build_object('id', gen_random_uuid()::text, 'kind', 'text', 'body',
          'All content and products on [Business name] are provided "as is" without warranties of any kind, express or implied. Games, apps, and code may contain bugs. We are not liable for any damages arising from use of the Site or our products to the fullest extent permitted by law. External links are not endorsements.')
      ),
      false, false, 905, 'blocks'
    )
  ON CONFLICT (slug) DO NOTHING;
END $$;
