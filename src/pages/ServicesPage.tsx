import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ServicePurchaseBlock } from '../components/ServicePurchaseBlock';
import { ServiceRequestForm } from '../components/ServiceRequestForm';
import { SiteChrome } from '../components/SiteChrome';
import { fetchPublishedServices } from '../lib/servicesData';
import { serviceCategoryLabel } from '../lib/servicePricing';
import { supabaseConfigured } from '../lib/supabase';
import type { ServiceView } from '../types';

export function ServicesPage() {
  const [services, setServices] = useState<ServiceView[]>([]);
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void fetchPublishedServices().then((rows) => {
      if (!cancelled) {
        setServices(rows);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const byCategory = useMemo(() => {
    const map = new Map<string, ServiceView[]>();
    for (const s of services) {
      const cat = s.category || 'other';
      if (!map.has(cat)) map.set(cat, []);
      map.get(cat)!.push(s);
    }
    return [...map.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  }, [services]);

  return (
    <SiteChrome navExtra={<Link to="/">← Hub</Link>}>
      <div className="services-page">
        <header className="services-hero">
          <p className="services-hero__eyebrow">Commission · Build · Support</p>
          <h1 className="header-title services-hero__title">Services &amp; gigs</h1>
          <p className="services-hero__lead">
            Games, websites, apps, assets, tips, and merch — pay through Stripe when configured, or send a project brief
            and we will quote you.
          </p>
        </header>

        {!supabaseConfigured ? (
          <p className="empty-state">Connect Supabase to load the services catalog (migration 025).</p>
        ) : loading ? (
          <p className="empty-state">Loading services…</p>
        ) : services.length === 0 ? (
          <p className="empty-state">
            No services published yet. Add rows in <Link to="/admin">Admin → Services</Link> or run migration 025.
          </p>
        ) : (
          <div className="services-catalog">
            {byCategory.map(([cat, items]) => (
              <section key={cat} className="services-category">
                <h2 className="services-category__title">{serviceCategoryLabel(cat)}</h2>
                <div className="services-grid">
                  {items.map((svc) => {
                    const open = expanded === svc.slug;
                    return (
                      <article
                        key={svc.slug}
                        className={`service-card admin-panel${open ? ' service-card--open' : ''}`}
                      >
                        <button
                          type="button"
                          className="service-card__head"
                          onClick={() => setExpanded(open ? null : svc.slug)}
                          aria-expanded={open}
                        >
                          <span className="service-card__icon" aria-hidden>
                            {svc.icon_emoji}
                          </span>
                          <span className="service-card__text">
                            <span className="service-card__title">{svc.title}</span>
                            <span className="service-card__tagline">{svc.tagline}</span>
                          </span>
                        </button>
                        {open ? (
                          <div className="service-card__body">
                            {svc.image_url ? (
                              <img src={svc.image_url} alt="" className="service-card__image" loading="lazy" />
                            ) : null}
                            <p className="service-card__desc">{svc.description}</p>
                            {svc.features.length > 0 ? (
                              <ul className="service-card__features">
                                {svc.features.map((f) => (
                                  <li key={f}>{f}</li>
                                ))}
                              </ul>
                            ) : null}
                            {(svc.deliverables || svc.turnaround) && (
                              <dl className="service-card__meta">
                                {svc.deliverables ? (
                                  <>
                                    <dt>Deliverables</dt>
                                    <dd>{svc.deliverables}</dd>
                                  </>
                                ) : null}
                                {svc.turnaround ? (
                                  <>
                                    <dt>Turnaround</dt>
                                    <dd>{svc.turnaround}</dd>
                                  </>
                                ) : null}
                              </dl>
                            )}
                            <div className="service-card__actions">
                              <ServicePurchaseBlock service={svc} />
                              {svc.request_form_enabled ? <ServiceRequestForm service={svc} /> : null}
                            </div>
                          </div>
                        ) : null}
                      </article>
                    );
                  })}
                </div>
              </section>
            ))}
          </div>
        )}

        <section className="services-inquiry admin-panel" style={{ marginTop: 32 }}>
          <h2 className="page-section-title">Not sure which option?</h2>
          <p className="admin-muted" style={{ lineHeight: 1.55 }}>
            Describe your project — we will reply by email. Signed-in users can also manage newsletter prefs on{' '}
            <Link to="/account">Account</Link>.
          </p>
          <ServiceRequestForm heading="Tell us what you are building" />
        </section>
      </div>
    </SiteChrome>
  );
}
