-- Native store: product variants (any size/color), quantity, physical vs
-- digital fulfillment, and site-level shipping config for Stripe Checkout.
--
-- No cart/inventory/orders tables (lean model): each checkout is one product
-- with an optional variant selection + quantity. Physical products collect a
-- shipping address and offer the flat shipping rates configured below.

-- ---- Product columns on site_services --------------------------------------
ALTER TABLE public.site_services
  ADD COLUMN IF NOT EXISTS product_type text NOT NULL DEFAULT 'service',
  ADD COLUMN IF NOT EXISTS variant_groups jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS requires_shipping boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS allow_quantity boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS max_quantity int NOT NULL DEFAULT 1;

COMMENT ON COLUMN public.site_services.product_type IS
  'digital | physical | service. Physical collects a shipping address at checkout.';
COMMENT ON COLUMN public.site_services.variant_groups IS
  'Option axes, e.g. [{"id","name":"Size","options":[{"id","label":"L","price_delta_cents":0,"sku":""}]}].';
COMMENT ON COLUMN public.site_services.requires_shipping IS
  'When true, Stripe Checkout collects a shipping address + offers site shipping rates.';
COMMENT ON COLUMN public.site_services.max_quantity IS
  'Upper bound for the storefront quantity stepper (1 = single item).';

-- ---- Site-level shipping config on site_settings ---------------------------
ALTER TABLE public.site_settings
  ADD COLUMN IF NOT EXISTS shipping jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.site_settings.shipping IS
  'Physical-product shipping: {enabled, allowed_countries:[ISO], rates:[{id,label,amount_cents,delivery_estimate}]}.';
