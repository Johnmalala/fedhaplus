import React from 'react';
import { Modal } from './Modal';
import { Button } from './Button';
import { AlertTriangle } from 'lucide-react';

interface ConfirmDeleteModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  itemName: string;
  loading: boolean;
  title?: string;
  message?: string;
  confirmText?: string;
  confirmVariant?: 'danger' | 'primary' | 'secondary';
}

export function ConfirmDeleteModal({ 
  isOpen, 
  onClose, 
  onConfirm, 
  itemName, 
  loading,
  title = "Confirm Action",
  message,
  confirmText = "Confirm",
  confirmVariant = "danger"
}: ConfirmDeleteModalProps) {
  return (
    <Modal isOpen={isOpen} onClose={onClose} title={title}>
      <div className="text-center">
        <AlertTriangle className="mx-auto h-12 w-12 text-red-500" />
        <p className="mt-4 text-gray-700 dark:text-gray-300">
          {message || <>Are you sure you want to proceed with this action for <strong className="font-semibold">{itemName}</strong>?</>}
        </p>
        <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
          This may not be reversible.
        </p>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button variant="secondary" onClick={onClose} disabled={loading}>
          Cancel
        </Button>
        <Button variant={confirmVariant} onClick={onConfirm} disabled={loading}>
          {loading ? 'Processing...' : confirmText}
        </Button>
      </div>
    </Modal>
  );
}
