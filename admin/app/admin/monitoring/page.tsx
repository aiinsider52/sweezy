import Card from '@/components/Card'

export default async function MonitoringPage() {
  const base = process.env.NEXT_PUBLIC_API_URL || 'https://sweezy.onrender.com/api/v1'
  const start1 = Date.now();
  const healthRes = await fetch(`${base}/health`, { cache: 'no-store' }).catch(()=>null)
  const healthMs = Date.now() - start1
  const start2 = Date.now();
  const readyRes = await fetch(`${base}/ready`, { cache: 'no-store' }).catch(()=>null)
  const readyMs = Date.now() - start2

  const healthOk = !!healthRes && healthRes.ok
  const readyOk = !!readyRes && readyRes.ok

  return (
    <section className="grid grid-cols-12 gap-6">
      <Card title="/health" className="col-span-12 md:col-span-4">
        <div className={healthOk ? 'text-green-400' : 'text-red-400'}>{healthOk ? 'OK' : 'DOWN'}</div>
        <div className="text-xs opacity-70">{healthMs} ms</div>
      </Card>
      <Card title="/ready" className="col-span-12 md:col-span-4">
        <div className={readyOk ? 'text-green-400' : 'text-red-400'}>{readyOk ? 'READY' : 'NOT READY'}</div>
        <div className="text-xs opacity-70">{readyMs} ms</div>
      </Card>
      <Card title="Notes" className="col-span-12">
        <ul className="list-disc pl-5 text-sm opacity-80">
          <li>Для продакшна можно подключить Sentry и вывести счётчики ошибок.</li>
          <li>Можно показывать последние деплои/версии, метрики БД и т.д.</li>
        </ul>
      </Card>
    </section>
  )
}


