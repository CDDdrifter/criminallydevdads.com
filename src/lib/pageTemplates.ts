import type { PageSection } from '../types';
import { newSectionId } from './pageSections';

/** Starter draft for a “Hire us” / services CMS page (`/#/p/hire-us`). */
export function hireUsPageDraft(): {
  slug: string;
  title: string;
  body: string;
  page_mode: 'blocks';
  sections: PageSection[];
  show_in_nav: boolean;
  sort_order: number;
  unlisted: boolean;
  show_on_apps_hub: boolean;
} {
  return {
    slug: 'hire-us',
    title: 'Hire Us',
    body: '',
    page_mode: 'blocks',
    show_in_nav: true,
    sort_order: 50,
    unlisted: false,
    show_on_apps_hub: false,
    sections: [
      {
        id: newSectionId(),
        kind: 'hero',
        title: 'Hire Criminally Dev Dads',
        subtitle: 'Game design, prototypes, Godot builds, and playful web experiences.',
        align: 'center',
      },
      {
        id: newSectionId(),
        kind: 'text',
        body: 'Tell us about your project — timeline, budget, and platform. We ship fast, iterate in public, and love weird ideas.',
      },
      {
        id: newSectionId(),
        kind: 'cta',
        title: 'Start a conversation',
        body: 'Email us with links to references or a one-pager. We reply within a few business days.',
        primary: { label: 'Contact', href: 'mailto:hello@criminallydevdads.com', external: true },
      },
      {
        id: newSectionId(),
        kind: 'feature_list',
        items: [
          { id: newSectionId(), title: 'Godot games', body: 'Playable builds for web and desktop.' },
          { id: newSectionId(), title: 'HTML apps', body: 'Tools, sandboxes, and interactive pages on this hub.' },
          { id: newSectionId(), title: 'Live ops', body: 'Updates, analytics, and monetization hooks you already have here.' },
        ],
      },
    ],
  };
}
