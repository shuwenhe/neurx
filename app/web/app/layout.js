import './globals.css';

export const metadata = {
  title: 'NeurX LLM',
  description: 'NeurX Next.js web UI for the S-based LLM backend',
};

export default function RootLayout({ children }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
