import Card from '@/components/Card'

export default async function MonitoringPage() {
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy-9xyk.onrender.com/api/v1'
  const start1 = Date.now();
  const c1 = new AbortController(); const t1 = setTimeout(()=>c1.abort(), 8000)
  const healthRes = await fetch(`${base}/health`, { cache: 'no-store', signal: c1.signal }).catch(()=>null)
  clearTimeout(t1)
  const healthMs = Date.now() - start1
  const start2 = Date.now();
  const c2 = new AbortController(); const t2 = setTimeout(()=>c2.abort(), 8000)
  const readyRes = await fetch(`${base}/ready`, { cache: 'no-store', signal: c2.signal }).catch(()=>null)
  clearTimeout(t2)
  const readyMs = Date.now() - start2

  const healthOk = !!healthRes && healthRes.ok
  const readyOk = !!readyRes && readyRes.ok

  return (
    <section className="space-y-8">
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
        <Card title="/health">
          <div className={healthOk ? 'text-green-400' : 'text-red-400'}>
            <div className="text-3xl font-semibold">{healthOk ? 'OK' : 'DOWN'}</div>
          </div>
          <div className="text-xs opacity-70 mt-1">{healthMs} ms</div>
        </Card>
        <Card title="/ready">
          <div className={readyOk ? 'text-green-400' : 'text-red-400'}>
            <div className="text-3xl font-semibold">{readyOk ? 'READY' : 'NOT READY'}</div>
          </div>
          <div className="text-xs opacity-70 mt-1">{readyMs} ms</div>
        </Card>
      </div>
      <Card title="Notes">
        <ul className="list-disc pl-5 text-sm opacity-80 space-y-1">
          <li>Для продакшна можно подключить Sentry и вывести счётчики ошибок.</li>
          <li>Можно показывать последние деплои/версии, метрики БД и т.д.</li>
        </ul>
      </Card>
    </section>
  )
}


