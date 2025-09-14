import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Student } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical, Pencil, Trash2 } from 'lucide-react';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { Menu, Transition } from '@headlessui/react';
import { ConfirmDeleteModal } from '../components/ui/ConfirmDeleteModal';

interface StudentsPageProps {
  businessId: string;
}

export default function Students({ businessId }: StudentsPageProps) {
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingStudent, setEditingStudent] = useState<Student | null>(null);
  const [deletingStudent, setDeletingStudent] = useState<Student | null>(null);
  const [deleteLoading, setDeleteLoading] = useState(false);

  const [studentForm, setNewStudent] = useState({
    first_name: '',
    last_name: '',
    admission_number: '',
    class_level: '',
    parent_name: '',
    parent_phone: '',
    fee_amount: '',
  });

  const fetchStudents = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('students')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setStudents(data || []);
    } catch (error) {
      console.error('Error fetching students:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchStudents();
    }
  }, [businessId, fetchStudents]);

  useEffect(() => {
    if (editingStudent) {
      setNewStudent({
        first_name: editingStudent.first_name,
        last_name: editingStudent.last_name,
        admission_number: editingStudent.admission_number,
        class_level: editingStudent.class_level,
        parent_name: editingStudent.parent_name,
        parent_phone: editingStudent.parent_phone,
        fee_amount: String(editingStudent.fee_amount),
      });
    } else {
      setNewStudent({ first_name: '', last_name: '', admission_number: '', class_level: '', parent_name: '', parent_phone: '', fee_amount: '' });
    }
  }, [editingStudent, isModalOpen]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setNewStudent(prev => ({ ...prev, [name]: value }));
  };

  const openAddModal = () => {
    setEditingStudent(null);
    setIsModalOpen(true);
  };

  const openEditModal = (student: Student) => {
    setEditingStudent(student);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingStudent(null);
  };

  const handleSaveStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    const studentData = {
      ...studentForm,
      business_id: businessId,
      fee_amount: parseFloat(studentForm.fee_amount),
    };

    try {
      let savedStudent: Student | null = null;
      if (editingStudent) {
        const { data, error } = await supabase
          .from('students')
          .update(studentData)
          .eq('id', editingStudent.id)
          .select()
          .single();
        if (error) throw error;
        savedStudent = data;
        setStudents(prev => prev.map(s => s.id === savedStudent!.id ? savedStudent! : s));
      } else {
        const { data, error } = await supabase
          .from('students')
          .insert({ ...studentData, is_active: true, fee_status: 'pending' })
          .select()
          .single();
        if (error) throw error;
        savedStudent = data;
        setStudents(prev => [savedStudent!, ...prev]);
      }
      closeModal();
    } catch (error) {
      console.error('Error saving student:', error);
    }
  };

  const handleDeleteStudent = async () => {
    if (!deletingStudent) return;
    setDeleteLoading(true);
    try {
      const { error } = await supabase.from('students').delete().eq('id', deletingStudent.id);
      if (error) throw error;
      setStudents(prev => prev.filter(s => s.id !== deletingStudent.id));
      setDeletingStudent(null);
    } catch (error) {
      console.error('Error deleting student:', error);
    } finally {
      setDeleteLoading(false);
    }
  };

  const getBadgeVariant = (status: Student['fee_status']) => {
    switch (status) {
      case 'paid': return 'success';
      case 'pending': return 'warning';
      case 'overdue': return 'danger';
      default: return 'default';
    }
  }

  return (
    <div>
      <PageHeader
        title="Students"
        subtitle="Manage all student records and information."
        actions={
          <Button icon={<PlusIcon />} onClick={openAddModal}>
            Add Student
          </Button>
        }
      />
      <Card>
        <CardContent>
          {loading ? (
            <p>Loading students...</p>
          ) : students.length === 0 ? (
             <div className="text-center py-12">
                <h3 className="text-lg font-medium text-gray-900 dark:text-white">No students found</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Get started by adding your first student.</p>
                <div className="mt-6">
                    <Button icon={<PlusIcon />} onClick={openAddModal}>
                        Add First Student
                    </Button>
                </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Student Name</TableHead>
                <TableHead>Admission No.</TableHead>
                <TableHead>Class</TableHead>
                <TableHead>Parent Phone</TableHead>
                <TableHead>Fee Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {students.map((student) => (
                  <TableRow key={student.id}>
                    <TableCell><div className="font-medium">{student.first_name} {student.last_name}</div></TableCell>
                    <TableCell>{student.admission_number}</TableCell>
                    <TableCell>{student.class_level}</TableCell>
                    <TableCell>{student.parent_phone}</TableCell>
                    <TableCell>
                      <Badge variant={getBadgeVariant(student.fee_status)}>
                        {student.fee_status}
                      </Badge>
                    </TableCell>
                    <TableCell className="text-right">
                      <Menu as="div" className="relative inline-block text-left">
                        <Menu.Button as={Button} variant="ghost" size="sm" icon={<MoreVertical className="h-4 w-4" />} />
                        <Transition as={React.Fragment} enter="transition ease-out duration-100" enterFrom="transform opacity-0 scale-95" enterTo="transform opacity-100 scale-100" leave="transition ease-in duration-75" leaveFrom="transform opacity-100 scale-100" leaveTo="transform opacity-0 scale-95">
                          <Menu.Items className="absolute right-0 z-10 mt-2 w-32 origin-top-right rounded-md bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 focus:outline-none">
                            <div className="px-1 py-1">
                              <Menu.Item>
                                {({ active }) => (
                                  <button onClick={() => openEditModal(student)} className={`${active ? 'bg-primary-100 dark:bg-gray-700' : ''} text-gray-900 dark:text-gray-100 group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                    <Pencil className="mr-2 h-4 w-4" /> Edit
                                  </button>
                                )}
                              </Menu.Item>
                              <Menu.Item>
                                {({ active }) => (
                                  <button onClick={() => setDeletingStudent(student)} className={`${active ? 'bg-red-100 dark:bg-red-700' : ''} text-red-700 dark:text-red-400 group flex w-full items-center rounded-md px-2 py-2 text-sm`}>
                                    <Trash2 className="mr-2 h-4 w-4" /> Delete
                                  </button>
                                )}
                              </Menu.Item>
                            </div>
                          </Menu.Items>
                        </Transition>
                      </Menu>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isModalOpen} onClose={closeModal} title={editingStudent ? "Edit Student" : "Add New Student"}>
        <form onSubmit={handleSaveStudent} className="space-y-4">
          <Input name="first_name" placeholder="First Name" value={studentForm.first_name} onChange={handleInputChange} required />
          <Input name="last_name" placeholder="Last Name" value={studentForm.last_name} onChange={handleInputChange} required />
          <Input name="admission_number" placeholder="Admission Number" value={studentForm.admission_number} onChange={handleInputChange} required />
          <Input name="class_level" placeholder="Class (e.g., Form 1)" value={studentForm.class_level} onChange={handleInputChange} required />
          <Input name="parent_name" placeholder="Parent's Name" value={studentForm.parent_name} onChange={handleInputChange} required />
          <Input name="parent_phone" placeholder="Parent's Phone (254...)" value={studentForm.parent_phone} onChange={handleInputChange} required />
          <Input name="fee_amount" type="number" placeholder="Term Fee Amount" value={studentForm.fee_amount} onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={closeModal}>Cancel</Button>
            <Button type="submit">{editingStudent ? "Save Changes" : "Add Student"}</Button>
          </div>
        </form>
      </Modal>

      {deletingStudent && (
        <ConfirmDeleteModal
          isOpen={!!deletingStudent}
          onClose={() => setDeletingStudent(null)}
          onConfirm={handleDeleteStudent}
          itemName={`${deletingStudent.first_name} ${deletingStudent.last_name}`}
          loading={deleteLoading}
          title="Delete Student"
          message={`Are you sure you want to delete ${deletingStudent.first_name}? This will also delete all associated fee payments.`}
          confirmText="Delete"
        />
      )}
    </div>
  );
}
