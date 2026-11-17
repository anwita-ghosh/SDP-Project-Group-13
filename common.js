const sb = supabase.createClient(LSF.url, LSF.key);
const $ = id => document.getElementById(id);
const inr = v => "₹" + Number(v || 0).toLocaleString("en-IN");
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
