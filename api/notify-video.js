export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ ok: false, error: 'Method not allowed' });
  }

  try {
    let payload;
    if (typeof req.body === 'string') {
      payload = JSON.parse(req.body);
    } else if (Buffer.isBuffer(req.body)) {
      payload = JSON.parse(req.body.toString());
    } else {
      payload = req.body;
    }

    const { cloudName, publicId } = payload;
    if (!cloudName || !publicId) {
      return res.status(400).json({ ok: false, error: 'Missing cloudName or publicId' });
    }

    // link video dari Cloudinary (public_id already bawah struktur handgesture/session-xxx)
    const videoUrl = `https://res.cloudinary.com/${cloudName}/video/upload/${publicId}.mp4`;
    const waktu = new Date().toLocaleString('id-ID', { timeZone: 'Asia/Jakarta' });

    // kirim email via Resend
    const resendRes = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Hand Gesture App <onboarding@resend.dev>',
        to: [process.env.TARGET_EMAIL],
        subject: `Recording Video Gesture - ${waktu}`,
        html: `
          <h2>Hand Gesture Recording Saved</h2>
          <p>Video recording dari session Anda telah selesai dan disimpan di Cloudinary.</p>
          <p><strong>Waktu:</strong> ${waktu} WIB</p>
          <p><strong>Link Video:</strong> <a href="${videoUrl}">${videoUrl}</a></p>
          <p>Video akan tersedia selama 30 hari di Cloudinary (sesuai free tier limit).</p>
          <hr>
          <small>Automated dari Hand Gesture Particle Control App</small>
        `,
      }),
    });

    const data = await resendRes.json();
    if (!resendRes.ok) {
      console.error('Resend error:', data);
      return res.status(resendRes.status).json({ ok: false, error: data });
    }
    return res.status(200).json({ ok: true, videoUrl, emailSent: data.id });
  } catch (err) {
    console.error('Handler error:', err);
    return res.status(500).json({ ok: false, error: String(err) });
  }
}
