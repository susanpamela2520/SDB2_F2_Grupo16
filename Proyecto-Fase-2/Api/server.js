import express from "express";
import dotenv from "dotenv";
import { queryWithFailover, getTxClient, shouldUseSequence, getActiveNode, forcePrimary, forceSecondary } from "./db.js";

dotenv.config();
const app = express();
app.use(express.json());

let useSequenceFlag = false;
(async () => {
  try {
    useSequenceFlag = await shouldUseSequence();
    if ((process.env.USE_SEQUENCE || "").toLowerCase() === "true") useSequenceFlag = true;
    console.log(`[init] USE_SEQUENCE = ${useSequenceFlag}`);
  } catch (e) {
    console.error("[init] Detección de secuencia falló:", e.message);
  }
})();

app.get("/health", async (_req, res) => {
  try {
    await queryWithFailover("SELECT 1");
    res.status(200).json({ ok: true, active_node: getActiveNode() });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message, active_node: getActiveNode() });
  }
});

app.get("/active-node", (_req, res) => {
  res.json({ active_node: getActiveNode() });
});

app.post("/switch-to-primary", (_req, res) => {
  forcePrimary();
  res.json({ ok: true, active_node: getActiveNode() });
});
app.post("/switch-to-secondary", (_req, res) => {
  forceSecondary();
  res.json({ ok: true, active_node: getActiveNode() });
});

app.post("/generos", async (req, res) => {
  const { id_genero, genero } = req.body || {};
  if (!genero || typeof genero !== "string" || genero.trim() === "") {
    return res.status(400).json({ ok: false, error: "Campo 'genero' es requerido (string no vacío)." });
  }

  const { client, node } = await getTxClient();
  try {
    await client.query("BEGIN");

    let sql, params;
    if (Number.isInteger(id_genero)) {
      sql = `INSERT INTO public.generos (id_genero, genero) VALUES ($1, $2) RETURNING id_genero, genero;`;
      params = [id_genero, genero.trim()];
    } else if (useSequenceFlag) {
      sql = `INSERT INTO public.generos (genero) VALUES ($1) RETURNING id_genero, genero;`;
      params = [genero.trim()];
    } else {
      await client.query("LOCK TABLE public.generos IN SHARE ROW EXCLUSIVE MODE;");
      const r = await client.query("SELECT COALESCE(MAX(id_genero), 0) + 1 AS next_id FROM public.generos;");
      const nextId = r.rows[0].next_id;
      sql = `INSERT INTO public.generos (id_genero, genero) VALUES ($1, $2) RETURNING id_genero, genero;`;
      params = [nextId, genero.trim()];
    }

    const ins = await client.query(sql, params);
    await client.query("COMMIT");
    res.status(201).json({ ok: true, data: ins.rows[0], node_used: node });
  } catch (e) {
    await client.query("ROLLBACK");
    if (String(e.code) === "23505") {
      return res.status(409).json({ ok: false, error: "Conflicto de clave primaria (id_genero duplicado)." });
    }
    res.status(400).json({ ok: false, error: e.message });
  } finally {
    client.release();
  }
});

const PORT = Number(process.env.PORT || 5000);
app.listen(PORT, () => {
  console.log(`API generos escuchando en :${PORT}`);
});
