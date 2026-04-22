'use client';

import { useEffect, useState } from 'react';
import ProtectedRoute from '@/components/ProtectedRoute';
import ExpenseModal from '@/components/ExpenseModal';

export default function TransactionsPage() {
  const [transactions, setTransactions] = useState([]);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingTx, setEditingTx] = useState<any>(null);

  useEffect(() => {
    // Mocking an API call
    setTransactions([
      { id: 'tx-1', date: '2026-04-20', type: 'expense', category: 'Food & Dining', amount: 45.0, currency: 'USD', note: 'Lunch with team' },
      { id: 'tx-2', date: '2026-04-19', type: 'expense', category: 'Transport', amount: 120.0, currency: 'AUD', note: 'Uber to airport' },
      { id: 'tx-3', date: '2026-04-18', type: 'income', category: 'Salary', amount: 1500.0, currency: 'AUD', note: 'April Payment' },
      { id: 'tx-4', date: '2026-04-15', type: 'expense', category: 'Utilities', amount: 85.5, currency: 'AUD', note: 'Internet Bill' },
    ] as any);
  }, []);

  return (
    <ProtectedRoute>
      <div className="p-8 max-w-6xl mx-auto">
        <header className="mb-8 flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Transactions</h1>
            <p className="text-gray-500">Manage your raw data and edits</p>
          </div>
          <button 
            onClick={() => { setEditingTx(null); setIsModalOpen(true); }}
            className="px-4 py-2 bg-indigo-600 text-white rounded-md font-medium shadow-sm hover:bg-indigo-700 transition"
          >
            + Add Expense
          </button>
        </header>

        <div className="bg-white border border-gray-200 rounded-lg shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="bg-gray-50 border-b border-gray-200 text-sm">
                  <th className="p-4 font-semibold text-gray-600">Date</th>
                  <th className="p-4 font-semibold text-gray-600">Type</th>
                  <th className="p-4 font-semibold text-gray-600">Category</th>
                  <th className="p-4 font-semibold text-gray-600">Amount</th>
                  <th className="p-4 font-semibold text-gray-600">Note</th>
                  <th className="p-4 font-semibold text-gray-600 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {transactions.map((tx: any) => (
                  <tr key={tx.id} className="hover:bg-gray-50/50 transition-colors">
                    <td className="p-4 text-sm text-gray-600">{tx.date}</td>
                    <td className="p-4">
                      <span className={`inline-flex items-center px-2 py-1 rounded-full text-xs font-medium ${tx.type === 'income' ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'}`}>
                        {tx.type}
                      </span>
                    </td>
                    <td className="p-4 text-sm text-gray-900 font-medium">{tx.category}</td>
                    <td className="p-4 text-sm font-semibold">
                      {tx.amount.toFixed(2)} <span className="text-gray-500 font-normal">{tx.currency}</span>
                    </td>
                    <td className="p-4 text-sm text-gray-500 max-w-[200px] truncate">{tx.note || '-'}</td>
                    <td className="p-4 text-right">
                      <button 
                        onClick={() => { setEditingTx(tx); setIsModalOpen(true); }}
                        className="text-sm text-indigo-600 hover:text-indigo-800 font-medium"
                      >
                        Edit
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {transactions.length === 0 && (
            <div className="p-8 text-center text-gray-500">No transactions found.</div>
          )}
        </div>
      </div>
      <ExpenseModal 
        isOpen={isModalOpen} 
        onClose={() => { setIsModalOpen(false); setEditingTx(null); }} 
        initialData={editingTx} 
      />
    </ProtectedRoute>
  );
}
