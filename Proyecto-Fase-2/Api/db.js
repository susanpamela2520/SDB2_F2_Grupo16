import pg from "pg";
import dotenv from "dotenv";
dotenv.config();

const { Pool } = pg;

const FAILOVER_ERRORS = new Set([
  "ECONNREFUSED","ECONNRESET","ETIMEDOUT","EHOSTUNREACH","ENETUNREACH",
  "57P01","57P02","57P03","08003","08006","08001","08004","08007"
]);

function makePool(host, port) {
  const pool = new Pool({
    host,
    port: Number(port),
    user: process.env.PGUSER,
    password: process.env.PGPASSWORD,
    database: process.env.PGDATABASE,
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 5000
  });

  pool.on('error', (err, client) => {
    console.error(`⚠️  Error en pool (${host}:${port}):`, err.code || err.message);
  });

  return pool;
}

const pools = {
  primary: makePool(process.env.PGHOST_PRIMARY, process.env.PGPORT_PRIMARY),
  secondary: makePool(process.env.PGHOST_SECONDARY, process.env.PGPORT_SECONDARY)
};

let activeNode = "primary";
export function getActiveNode() { return activeNode; }

function switchNode(newNode) {
  if (activeNode !== newNode) {
    const previous = activeNode;
    activeNode = newNode;
    console.log(`🔄 Cambio de nodo: ${previous} → ${activeNode}`);
  }
}

export async function queryWithFailover(text, params, clientOpt) {
  if (clientOpt?.client) return clientOpt.client.query(text, params);
  
  try {
    return await pools[activeNode].query(text, params);
  } catch (e) {
    const code = e.code || e.errno || e.message;
    console.error(`❌ Error en ${activeNode}:`, code);

    if (!FAILOVER_ERRORS.has(code)) throw e;
    
    switchNode(activeNode === "primary" ? "secondary" : "primary");
    return await pools[activeNode].query(text, params);
  }
}

export async function getTxClient() {
  const maxRetries = 2;
  let lastError;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const c = await pools[activeNode].connect();
      return { client: c, node: activeNode };
    } catch (e) {
      lastError = e;
      const code = e.code || e.errno || e.message;
      console.error(`❌ Error al conectar a ${activeNode} (intento ${attempt + 1}/${maxRetries}):`, code);
      
      if (!FAILOVER_ERRORS.has(code)) throw e;
      
      switchNode(activeNode === "primary" ? "secondary" : "primary");
    }
  }

  throw lastError;
}

export async function shouldUseSequence() {
  if ((process.env.USE_SEQUENCE || "").toLowerCase() === "true") return true;
  try {
    const r = await queryWithFailover(`
      SELECT
        EXISTS (SELECT 1 FROM pg_class WHERE relkind='S' AND relname='generos_id_seq') AS has_seq,
        (SELECT column_default IS NOT NULL
         FROM information_schema.columns
         WHERE table_schema='public' AND table_name='generos' AND column_name='id_genero') AS has_def;
    `);
    const row = r.rows?.[0] || {};
    return row.has_seq === true && row.has_def === true;
  } catch {
    return false;
  }
}

export function forcePrimary() {
  switchNode("primary");
}

export function forceSecondary() {
  switchNode("secondary");
}

process.on('SIGTERM', async () => {
  console.log('📛 Cerrando pools de conexiones...');
  await pools.primary.end();
  await pools.secondary.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('📛 Cerrando pools de conexiones...');
  await pools.primary.end();
  await pools.secondary.end();
  process.exit(0);
});