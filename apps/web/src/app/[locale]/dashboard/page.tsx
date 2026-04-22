'use client';

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';

export default function DashboardPage() {
  const [balance, setBalance] = useState(0);
  const [transactions, setTransactions] = useState([]);

  useEffect(() => {
    // In a real scenario, we'd fetch this from the NestJS /transactions API
    // using the token from the AuthContext. Mocking for now:
    setBalance(5430.25);
    setTransactions([
      { id: 1, date: '2026-04-20', type: 'expense', amount: 45.0, currency: 'USD', category: 'Food' },
      { id: 2, date: '2026-04-19', type: 'expense', amount: 120.0, currency: 'AUD', category: 'Transport' },
      { id: 3, date: '2026-04-18', type: 'income', amount: 1500.0, currency: 'AUD', category: 'Salary' },
    ]);
  }, []);

  return (
    <ProtectedRoute>
      <div className="p-8 max-w-5xl mx-auto space-y-6">
        <header className="mb-8 flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Dashboard</h1>
            <p className="text-gray-500">Your financial overview</p>
          </div>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="md:col-span-1 border rounded-xl p-6 bg-white shadow-sm border-gray-100 flex flex-col justify-center">
            <h2 className="text-sm font-medium text-gray-500 uppercase tracking-wider mb-2">Total Balance</h2>
            <div className="flex items-baseline space-x-2">
              <span className="text-4xl font-extrabold text-gray-900">${balance.toFixed(2)}</span>
              <span className="text-gray-400 font-medium">AUD</span>
            </div>
            <div className="mt-4 flex gap-2">
              <div className="bg-green-50 text-green-700 px-2 py-1 rounded-md text-xs font-semibold">+ $1.5k this month</div>
            </div>
          </div>

          <div className="md:col-span-2 border rounded-xl p-6 bg-white shadow-sm border-gray-100 min-h-[250px] relative flex flex-col">
            <h2 className="text-sm font-medium text-gray-500 uppercase tracking-wider mb-4">Activity (Line Chart Placeholder)</h2>
            <div className="flex-1 flex items-end justify-between px-2 pb-2">
              {/* Mock Bar/Line visual */}
              {[40, 70, 45, 90, 65, 100, 85].map((h, i) => (
                <div key={i} className="flex flex-col items-center gap-2">
                   <div 
                     className="w-10 bg-indigo-500 rounded-t-sm opacity-80"
                     style={{ height: `${h}%` }}
                   ></div>
                   <span className="text-xs text-gray-400">Apr {15 + i}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-6">
           <div className="border rounded-xl bg-white shadow-sm border-gray-100 overflow-hidden">
             <div className="px-6 py-4 border-b border-gray-100">
               <h2 className="font-semibold text-gray-800">Recent Transactions</h2>
             </div>
             <div className="divide-y divide-gray-50">
               {transactions.map((tx: any) => (
                 <div key={tx.id} className="p-4 px-6 flex justify-between items-center hover:bg-gray-50 transition-colors">
                   <div className="flex items-center gap-3">
                     <div className={`p-2 rounded-full ${tx.type === 'income' ? 'bg-green-100' : 'bg-red-100'}`}>
                       <span className="text-xl">💰</span>
                     </div>
                     <div>
                       <p className="font-medium text-gray-900">{tx.category}</p>
                       <p className="text-xs text-gray-500">{tx.date}</p>
                     </div>
                   </div>
                   <div className={`font-semibold ${tx.type === 'income' ? 'text-green-600' : 'text-gray-900'}`}>
                     {tx.type === 'income' ? '+' : '-'}${tx.amount.toFixed(2)} {tx.currency}
                   </div>
                 </div>
               ))}
             </div>
           </div>
        </div>
      </div>
    </ProtectedRoute>
  );
}
