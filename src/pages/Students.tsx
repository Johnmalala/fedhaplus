import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Student } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';

// This component now needs the business context
interface StudentsPageProps {
  businessId: string;
}

export default function Students({ businessId }: StudentsPageProps) {
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newStudent, setNewStudent] = useState({
    first_name: '',
    last_name: '',
    admission_number: '',
    class_level: '',
    parent_name: '',
    parent_phone: '',
    fee_amount: 0,
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

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setNewStudent(prev => ({ ...prev, [name]: value }));
  };

  const handleAddStudent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    try {
      const { data, error } = await supabase
        .from('students')
        .insert([{ ...newStudent, business_id: businessId, is_active: true, fee_status: 'Unpaid' }])
        .select()
        .single();
      
      if (error) throw error;

      // TODO: Trigger SMS to parent via Supabase Edge Function
      console.log(`Simulating SMS to ${newStudent.parent_phone}: Mwanao amesajiliwa...`);
      
      setStudents(prev => [data, ...prev]);
      setIsModalOpen(false);
      setNewStudent({ first_name: '', last_name: '', admission_number: '', class_level: '', parent_name: '', parent_phone: '', fee_amount: 0 });
    } catch (error) {
      console.error('Error adding student:', error);
    }
  };

  const getBadgeVariant = (status: Student['fee_status']) => {
    switch (status) {
      case 'paid': return 'success';
      case 'pending': return 'warning'; // Assuming 'Partial' maps to 'pending'
      case 'overdue': return 'danger';
      default: return 'danger'; // 'Unpaid'
    }
  }

  return (
    <div>
      <PageHeader
        title="Students"
        subtitle="Manage all student records and information."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
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
                    <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
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
                      <Button variant="ghost" size="sm" icon={<MoreVertical />} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </CardContent>
      </Card>

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Add New Student">
        <form onSubmit={handleAddStudent} className="space-y-4">
          <Input name="first_name" placeholder="First Name" onChange={handleInputChange} required />
          <Input name="last_name" placeholder="Last Name" onChange={handleInputChange} required />
          <Input name="admission_number" placeholder="Admission Number" onChange={handleInputChange} required />
          <Input name="class_level" placeholder="Class (e.g., Form 1)" onChange={handleInputChange} required />
          <Input name="parent_name" placeholder="Parent's Name" onChange={handleInputChange} required />
          <Input name="parent_phone" placeholder="Parent's Phone (254...)" onChange={handleInputChange} required />
          <Input name="fee_amount" type="number" placeholder="Term Fee Amount" onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Add Student</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
