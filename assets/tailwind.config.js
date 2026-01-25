/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './js/**/*.js',
    '../lib/muadzin_web.ex',
    '../lib/muadzin_web/**/*.*ex'
  ],
  theme: {
    extend: {
      animation: {
        'pulse-banner': 'pulse-banner 2s ease-in-out infinite',
        'speaker-pulse': 'speaker-pulse 1.5s ease-in-out infinite',
      },
    },
  },
  plugins: [],
}
