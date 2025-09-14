import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Room } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent, CardFooter } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon } from 'lucide-react';

interface RoomsPageProps {
  businessId: string;
}

export default function Rooms({ businessId }: RoomsPageProps) {
  const [rooms, setRooms] = useState<Room[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [newRoom, setNewRoom] = useState({
    room_number: '',
    room_type: 'Single',
    rate_per_night: '',
    capacity: '1',
  });

  const fetchRooms = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('rooms')
        .select('*')
        .eq('business_id', businessId)
        .order('room_number', { ascending: true });

      if (error) throw error;
      setRooms(data || []);
    } catch (error) {
      console.error('Error fetching rooms:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchRooms();
    }
  }, [businessId, fetchRooms]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setNewRoom(prev => ({ ...prev, [name]: value }));
  };

  const handleAddRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId) return;

    try {
      const { data, error } = await supabase
        .from('rooms')
        .insert([{
          ...newRoom,
          business_id: businessId,
          rate_per_night: parseFloat(newRoom.rate_per_night),
          capacity: parseInt(newRoom.capacity, 10),
          status: 'Available',
          is_active: true,
          amenities: [], // Default value
        }])
        .select()
        .single();
      
      if (error) throw error;
      
      setRooms(prev => [...prev, data].sort((a, b) => a.room_number.localeCompare(b.room_number)));
      setIsModalOpen(false);
      setNewRoom({ room_number: '', room_type: 'Single', rate_per_night: '', capacity: '1' });
    } catch (error) {
      console.error('Error adding room:', error);
      alert(`Failed to add room: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const getStatusVariant = (status: Room['status']) => {
    switch (status) {
      case 'Available': return 'success';
      case 'Occupied': return 'danger';
      case 'Cleaning': return 'warning';
      case 'Maintenance': return 'default';
      default: return 'default';
    }
  };

  if (loading) {
    return <div className="text-center py-12">Loading rooms...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Rooms"
        subtitle="Manage all hotel rooms and their status."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            Add Room
          </Button>
        }
      />
      {rooms.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Rooms Found</h3>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Get started by adding your first room.</p>
            <div className="mt-6">
              <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>Add First Room</Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
          {rooms.map((room) => (
            <Card key={room.id} className="flex flex-col">
              <CardContent className="flex-grow pt-6">
                <div className="flex justify-between items-start">
                  <div>
                    <p className="text-sm text-gray-500 dark:text-gray-400">{room.room_type}</p>
                    <h3 className="text-xl font-bold text-gray-900 dark:text-white">Room {room.room_number}</h3>
                  </div>
                  <Badge variant={getStatusVariant(room.status)}>
                    {room.status}
                  </Badge>
                </div>
              </CardContent>
              <CardFooter className="flex justify-between items-center">
                <p className="font-semibold text-gray-800 dark:text-gray-200">KSh {room.rate_per_night.toLocaleString()}</p>
                <Button size="sm" variant="secondary">Manage</Button>
              </CardFooter>
            </Card>
          ))}
        </div>
      )}

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Add New Room">
        <form onSubmit={handleAddRoom} className="space-y-4">
          <Input name="room_number" placeholder="Room Number (e.g., 101)" onChange={handleInputChange} required />
          <select name="room_type" value={newRoom.room_type} onChange={handleInputChange} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
            <option>Single</option>
            <option>Double</option>
            <option>Suite</option>
            <option>Family</option>
          </select>
          <Input name="rate_per_night" type="number" placeholder="Rate per Night (KSh)" onChange={handleInputChange} required />
          <Input name="capacity" type="number" placeholder="Capacity (guests)" onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Add Room</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
