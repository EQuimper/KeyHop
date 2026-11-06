import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://keyhop.equimper.com',
  integrations: [
    starlight({
      title: 'KeyHop',
      description: 'Click controls and select text on your Mac from the keyboard.',
      favicon: '/favicon.svg',
      logo: { src: './src/assets/mark.svg' },
      customCss: [
        '@fontsource-variable/archivo/wdth.css',
        '@fontsource-variable/martian-mono/index.css',
        './src/styles/docs.css',
      ],
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/EQuimper/KeyHop' }],
      editLink: { baseUrl: 'https://github.com/EQuimper/KeyHop/edit/main/website/' },
      sidebar: [
        {
          label: 'Start here',
          items: [
            { label: 'Get started', slug: 'docs' },
            { label: 'Install', slug: 'docs/install' },
            { label: 'Permissions', slug: 'docs/permissions' },
          ],
        },
        {
          label: 'Use KeyHop',
          items: [
            { label: 'Click controls', slug: 'docs/click' },
            { label: 'Click any point', slug: 'docs/grid' },
            { label: 'Select and copy text', slug: 'docs/select-text' },
          ],
        },
        {
          label: 'Customize',
          items: [
            { label: 'Keymaps', slug: 'docs/keymaps' },
            { label: 'Settings', slug: 'docs/settings' },
          ],
        },
        {
          label: 'Reference',
          items: [
            { label: 'Keyboard reference', slug: 'docs/keyboard' },
            { label: 'Troubleshooting', slug: 'docs/troubleshooting' },
            { label: 'Contributing', slug: 'docs/contributing' },
          ],
        },
      ],
    }),
  ],
});
