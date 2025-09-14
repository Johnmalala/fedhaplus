import React, { useState, useEffect, useCallback } from 'react';
import { supabase, type Booking, type Room, type Listing } from '../lib/supabase';
import PageHeader from '../components/PageHeader';
import { Card, CardContent } from '../components/ui/Card';
import { Button } from '../components/ui/Button';
import { Table, TableHeader, TableHead, TableBody, TableRow, TableCell } from '../components/ui/Table';
import { Badge } from '../components/ui/Badge';
import { Modal } from '../components/ui/Modal';
import { Input } from '../components/ui/Input';
import { PlusIcon, MoreVertical } from 'lucide-react';
import { format, differenceInDays } from 'date-fns';

interface BookingsPageProps {
  businessId: string;
}

type BookingWithRelations = Booking & {
  rooms: { room_number: string } | null;
  listings: { name: string } | null;
};

export default function Bookings({ businessId }: BookingsPageProps) {
  const [bookings, setBookings] = useState<BookingWithRelations[]>([]);
  const [availableRooms, setAvailableRooms] = useState<Room[]>([]);
  const [availableListings, setAvailableListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);

  const [newBooking, setNewBooking] = useState({
    guest_name: '',
    guest_phone: '',
    check_in_date: new Date().toISOString().split('T')[0],
    check_out_date: '',
    guests_count: '1',
    booking_type: 'room', // 'room' or 'listing'
    booking_target_id: '', // room_id or listing_id
    total_amount: '',
  });

  const fetchBookings = useCallback(async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase
        .from('bookings')
        .select('*, rooms(room_number), listings(name)')
        .eq('business_id', businessId)
        .order('created_at', { ascending: false });

      if (error) throw error;
      setBookings(data as BookingWithRelations[] || []);
    } catch (error) {
      console.error('Error fetching bookings:', error);
    } finally {
      setLoading(false);
    }
  }, [businessId]);

  const fetchAvailability = useCallback(async () => {
    try {
      const { data: roomsData, error: roomsError } = await supabase.from('rooms').select('*').eq('business_id', businessId).eq('status', 'Available');
      if (roomsError) throw roomsError;
      setAvailableRooms(roomsData || []);

      const { data: listingsData, error: listingsError } = await supabase.from('listings').select('*').eq('business_id', businessId).eq('status', 'Listed');
      if (listingsError) throw listingsError;
      setAvailableListings(listingsData || []);
    } catch (error) {
      console.error('Error fetching availability:', error);
    }
  }, [businessId]);

  useEffect(() => {
    if (businessId) {
      fetchBookings();
      fetchAvailability();
    }
  }, [businessId, fetchBookings, fetchAvailability]);
  
  useEffect(() => {
    // Auto-calculate total amount
    if (newBooking.check_in_date && newBooking.check_out_date && newBooking.booking_target_id) {
      const nights = differenceInDays(new Date(newBooking.check_out_date), new Date(newBooking.check_in_date));
      if (nights > 0) {
        let rate = 0;
        if (newBooking.booking_type === 'room') {
          const room = availableRooms.find(r => r.id === newBooking.booking_target_id);
          rate = room?.rate_per_night || 0;
        } else {
          const listing = availableListings.find(l => l.id === newBooking.booking_target_id);
          rate = listing?.rate_per_night || 0;
        }
        setNewBooking(prev => ({ ...prev, total_amount: String(nights * rate) }));
      } else {
        setNewBooking(prev => ({ ...prev, total_amount: '' }));
      }
    }
  }, [newBooking.check_in_date, newBooking.check_out_date, newBooking.booking_target_id, newBooking.booking_type, availableRooms, availableListings]);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setNewBooking(prev => ({ ...prev, [name]: value }));
  };
  
  const handleBookingTypeChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setNewBooking(prev => ({ ...prev, booking_type: e.target.value, booking_target_id: '', total_amount: '' }));
  };

  const handleAddBooking = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!businessId || !newBooking.booking_target_id) return;

    try {
      const { error } = await supabase.rpc('create_booking', {
        p_business_id: businessId,
        p_guest_name: newBooking.guest_name,
        p_guest_phone: newBooking.guest_phone,
        p_check_in_date: newBooking.check_in_date,
        p_check_out_date: newBooking.check_out_date,
        p_guests_count: parseInt(newBooking.guests_count, 10),
        p_total_amount: parseFloat(newBooking.total_amount),
        p_room_id: newBooking.booking_type === 'room' ? newBooking.booking_target_id : null,
        p_listing_id: newBooking.booking_type === 'listing' ? newBooking.booking_target_id : null,
      });
      
      if (error) throw error;
      
      await fetchBookings();
      await fetchAvailability();
      setIsModalOpen(false);
      setNewBooking({ guest_name: '', guest_phone: '', check_in_date: new Date().toISOString().split('T')[0], check_out_date: '', guests_count: '1', booking_type: 'room', booking_target_id: '', total_amount: '' });
    } catch (error) {
      console.error('Error adding booking:', error);
      alert(`Failed to add booking: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const getStatusVariant = (status: Booking['booking_status']) => {
    switch (status) {
      case 'Confirmed': return 'default';
      case 'Checked-in': return 'success';
      case 'Checked-out': return 'default';
      case 'Cancelled': return 'danger';
      default: return 'default';
    }
  };

  if (loading) {
    return <div className="text-center py-12">Loading bookings...</div>;
  }

  return (
    <div>
      <PageHeader
        title="Bookings"
        subtitle="Manage all guest bookings and reservations."
        actions={
          <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>
            New Booking
          </Button>
        }
      />
      <Card>
        <CardContent>
          {bookings.length === 0 ? (
            <div className="text-center py-12">
              <h3 className="text-lg font-medium text-gray-900 dark:text-white">No Bookings Found</h3>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Create your first guest booking.</p>
              <div className="mt-6">
                <Button icon={<PlusIcon />} onClick={() => setIsModalOpen(true)}>Create First Booking</Button>
              </div>
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableHead>Guest Name</TableHead>
                <TableHead>Details</TableHead>
                <TableHead>Check-in</TableHead>
                <TableHead>Check-out</TableHead>
                <TableHead>Status</TableHead>
                <TableHead><span className="sr-only">Actions</span></TableHead>
              </TableHeader>
              <TableBody>
                {bookings.map((booking) => (
                  <TableRow key={booking.id}>
                    <TableCell><div className="font-medium">{booking.guest_name}</div></TableCell>
                    <TableCell>{booking.rooms?.room_number ? `Room ${booking.rooms.room_number}` : booking.listings?.name}</TableCell>
                    <TableCell>{format(new Date(booking.check_in_date), 'MMM dd, yyyy')}</TableCell>
                    <TableCell>{format(new Date(booking.check_out_date), 'MMM dd, yyyy')}</TableCell>
                    <TableCell>
                      <Badge variant={getStatusVariant(booking.booking_status)}>
                        {booking.booking_status}
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

      <Modal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Create New Booking">
        <form onSubmit={handleAddBooking} className="space-y-4">
          <Input name="guest_name" placeholder="Guest Full Name" onChange={handleInputChange} required />
          <Input name="guest_phone" type="tel" placeholder="Guest Phone Number" onChange={handleInputChange} required />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Input name="check_in_date" type="date" value={newBooking.check_in_date} onChange={handleInputChange} required />
            <Input name="check_out_date" type="date" value={newBooking.check_out_date} onChange={handleInputChange} required />
          </div>
          <select name="booking_type" value={newBooking.booking_type} onChange={handleBookingTypeChange} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
            <option value="room">Room</option>
            <option value="listing">Airbnb Listing</option>
          </select>
          <select name="booking_target_id" value={newBooking.booking_target_id} onChange={handleInputChange} required className="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent dark:bg-gray-800 dark:text-white">
            <option value="" disabled>Select {newBooking.booking_type}</option>
            {newBooking.booking_type === 'room' ? (
              availableRooms.map(r => <option key={r.id} value={r.id}>Room {r.room_number} (KSh {r.rate_per_night})</option>)
            ) : (
              availableListings.map(l => <option key={l.id} value={l.id}>{l.name} (KSh {l.rate_per_night})</option>)
            )}
          </select>
          <Input name="total_amount" type="number" placeholder="Total Amount (KSh)" value={newBooking.total_amount} onChange={handleInputChange} required />
          <div className="flex justify-end space-x-2 pt-4">
            <Button type="button" variant="secondary" onClick={() => setIsModalOpen(false)}>Cancel</Button>
            <Button type="submit">Create Booking</Button>
          </div>
        </form>
      </Modal>
    </div>
  );
}
