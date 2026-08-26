import { useState, type CSSProperties } from 'react';
import { theme, playfair, inter, naira } from '../theme';

interface Notification {
  title: string;
  subtitle: string;
  time: string;
  isNew: boolean;
}

interface Payment {
  date: string;
  amount: number;
  status: string;
}

const initialNotifications: Notification[] = [
  { title: 'New Order Ready', subtitle: 'Mama Nkem Amala Palace — Order #1042', time: '2 min ago', isNew: true },
  { title: 'Delivery Confirmed', subtitle: 'Amara Okonkwo — Delivered', time: '15 min ago', isNew: false },
  { title: 'Pickup Assigned', subtitle: 'Suya Palace Abuja — Order #1039', time: '1 hour ago', isNew: false },
];

const initialPayments: Payment[] = [
  { date: '26 Aug 2026', amount: 1250, status: 'Paid' },
  { date: '25 Aug 2026', amount: 980, status: 'Paid' },
  { date: '24 Aug 2026', amount: 1420, status: 'Paid' },
  { date: '23 Aug 2026', amount: 1100, status: 'Paid' },
];

const statusOptions = [
  { label: 'Picked Up', value: 'picked_up' },
  { label: 'In Transit', value: 'in_transit' },
  { label: 'Delivered', value: 'delivered' },
];

export function RiderDashboard() {
  const [selectedTab, setSelectedTab] = useState<0 | 1>(0);
  const [notifications, setNotifications] = useState<Notification[]>(initialNotifications);
  const [payments] = useState<Payment[]>(initialPayments);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [statusUpdate, setStatusUpdate] = useState<{ status: string; time: string } | null>(null);

  const handleStatusUpdate = (status: string) => {
    setDialogOpen(false);
    const now = new Date().toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' });
    setStatusUpdate({ status, time: now });
    setNotifications((prev) => [
      { title: 'Status Updated', subtitle: `Order #1042 marked as ${status.replace('_', ' ')}`, time: 'just now', isNew: true },
      ...prev,
    ]);
  };

  return (
    <div style={pageStyle}>
      <div style={appContainerStyle}>
        <Header />
        <HeaderCard />
        <Tabs selectedTab={selectedTab} onSelect={setSelectedTab} />
        <div style={contentStyle}>
          {selectedTab === 0 ? (
            <NotificationsList notifications={notifications} />
          ) : (
            <PaymentsList payments={payments} />
          )}
        </div>
        {statusUpdate && (
          <StatusBar status={statusUpdate.status} time={statusUpdate.time} />
        )}
        {selectedTab === 0 && (
          <button style={fabStyle} onClick={() => setDialogOpen(true)}>
            <UpdateIcon />
            <span style={{ fontWeight: 700 }}>Update Status</span>
          </button>
        )}
      </div>
      {dialogOpen && <StatusDialog onClose={() => setDialogOpen(false)} onSelect={handleStatusUpdate} />}
    </div>
  );
}

function Header() {
  return (
    <header style={headerStyle}>
      <div style={headerLeftStyle}>
        <div style={logoCircleStyle}>
          <DeliveryIcon color={theme.gold} size={22} />
        </div>
        <h1 style={{ ...playfair(22, 700) }}>Rider Hub</h1>
      </div>
      <div style={{ position: 'relative' }}>
        <div style={bellButtonStyle}>
          <BellIcon color={theme.textPrimary} size={22} />
        </div>
        <span style={badgeStyle} />
      </div>
    </header>
  );
}

function HeaderCard() {
  return (
    <div style={headerCardStyle}>
      <h2 style={{ ...playfair(24, 700) }}>Daniel Okoro</h2>
      <p style={{ ...inter(13, 400, theme.textSecondary), marginTop: 4 }}>Active Rider • 142 Deliveries</p>
      <div style={miniStatsRowStyle}>
        <MiniStat label="Today" value="8" />
        <MiniStat label="Earnings" value={naira(2340)} />
        <MiniStat label="Rating" value="4.9" />
      </div>
    </div>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ textAlign: 'center' }}>
      <div style={{ ...inter(16, 700) }}>{value}</div>
      <div style={{ ...inter(10, 400, theme.textSecondary), marginTop: 2 }}>{label}</div>
    </div>
  );
}

function Tabs({ selectedTab, onSelect }: { selectedTab: 0 | 1; onSelect: (t: 0 | 1) => void }) {
  return (
    <div style={tabsContainerStyle}>
      <TabButton label="Notifications" active={selectedTab === 0} onClick={() => onSelect(0)} />
      <TabButton label="Payment History" active={selectedTab === 1} onClick={() => onSelect(1)} />
    </div>
  );
}

function TabButton({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      style={{
        ...tabButtonBaseStyle,
        ...(active
          ? { background: theme.deepBlack, border: `1px solid ${theme.gold}`, color: theme.gold, fontWeight: 700 }
          : { background: 'transparent', border: 'none', color: theme.textSecondary, fontWeight: 400 }),
      }}
    >
      {label}
    </button>
  );
}

function NotificationsList({ notifications }: { notifications: Notification[] }) {
  if (notifications.length === 0) {
    return <div style={emptyStyle}>No notifications yet</div>;
  }
  return (
    <div>
      {notifications.map((n, i) => (
        <div key={i} style={{ ...notificationStyle, borderColor: n.isNew ? `${theme.gold}55` : 'transparent' }}>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: '50%',
              background: n.isNew ? theme.error : theme.success,
              flexShrink: 0,
            }}
          />
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ ...inter(15, 600) }}>{n.title}</div>
            <div style={{ ...inter(12, 400, theme.textSecondary), marginTop: 4 }}>{n.subtitle}</div>
          </div>
          <span style={{ ...inter(11, 400, theme.textSecondary), flexShrink: 0 }}>{n.time}</span>
        </div>
      ))}
    </div>
  );
}

function PaymentsList({ payments }: { payments: Payment[] }) {
  if (payments.length === 0) {
    return <div style={emptyStyle}>No payment history yet</div>;
  }
  return (
    <div>
      {payments.map((p, i) => (
        <div key={i} style={paymentStyle}>
          <div style={paymentIconStyle}>
            <WalletIcon color={theme.gold} size={22} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ ...inter(15, 600) }}>{`Payment — ${p.date}`}</div>
            <div style={{ ...inter(12, 400, theme.textSecondary), marginTop: 2 }}>{`Status: ${p.status}`}</div>
          </div>
          <div style={{ ...inter(18, 700, theme.gold) }}>{naira(p.amount)}</div>
        </div>
      ))}
    </div>
  );
}

function StatusBar({ status, time }: { status: string; time: string }) {
  const isDelivered = status === 'delivered';
  return (
    <div style={{ ...statusBarStyle, borderColor: isDelivered ? theme.success : theme.gold }}>
      <span style={{ color: isDelivered ? theme.success : theme.gold, fontWeight: 700, fontSize: 13 }}>
        {status.replace('_', ' ').toUpperCase()}
      </span>
      <span style={{ ...inter(11, 400, theme.textSecondary) }}>{`Updated at ${time}`}</span>
    </div>
  );
}

function StatusDialog({ onClose, onSelect }: { onClose: () => void; onSelect: (status: string) => void }) {
  return (
    <div style={overlayStyle} onClick={onClose}>
      <div style={dialogStyle} onClick={(e) => e.stopPropagation()}>
        <h3 style={{ ...playfair(20, 600), marginBottom: 20 }}>Update Order Status</h3>
        {statusOptions.map((opt) => (
          <button
            key={opt.value}
            style={dialogOptionStyle}
            onClick={() => onSelect(opt.value)}
          >
            {opt.label}
          </button>
        ))}
        <button style={dialogCancelStyle} onClick={onClose}>Cancel</button>
      </div>
    </div>
  );
}

/* ---- Icons (inline SVG) ---- */

function DeliveryIcon({ color, size }: { color: string; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <circle cx="7" cy="17" r="2" /><circle cx="17" cy="17" r="2" />
      <path d="M5 17H3v-6h13v6M9 17h6M13 11h4l3 3v3h-2" />
    </svg>
  );
}

function BellIcon({ color, size }: { color: string; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function WalletIcon({ color, size }: { color: string; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 12V7H5a2 2 0 0 1 0-4h14v4" /><path d="M3 5v14a2 2 0 0 0 2 2h16v-5" />
      <path d="M18 12a2 2 0 0 0 0 4h4v-4Z" />
    </svg>
  );
}

function UpdateIcon() {
  return (
    <svg width={20} height={20} viewBox="0 0 24 24" fill="none" stroke={theme.deepBlack} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 2v6h-6" /><path d="M3 12a9 9 0 0 1 15-6.7L21 8" /><path d="M3 22v-6h6" /><path d="M21 12a9 9 0 0 1-15 6.7L3 16" />
    </svg>
  );
}

/* ---- Styles ---- */

const pageStyle: CSSProperties = {
  minHeight: '100vh',
  background: theme.deepBlack,
  paddingBottom: 100,
};

const appContainerStyle: CSSProperties = {
  maxWidth: 480,
  margin: '0 auto',
  padding: '0 24px',
};

const headerStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  padding: '24px 0 8px',
};

const headerLeftStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 12,
};

const logoCircleStyle: CSSProperties = {
  width: 38,
  height: 38,
  borderRadius: '50%',
  background: theme.surfaceElevated,
  border: `1px solid ${theme.gold}55`,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
};

const bellButtonStyle: CSSProperties = {
  width: 44,
  height: 44,
  borderRadius: '50%',
  background: theme.surfaceElevated,
  border: 'none',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
};

const badgeStyle: CSSProperties = {
  position: 'absolute',
  top: 10,
  right: 10,
  width: 8,
  height: 8,
  borderRadius: '50%',
  background: theme.error,
};

const headerCardStyle: CSSProperties = {
  margin: '8px 0 16px',
  padding: '24px',
  borderRadius: 28,
  background: `linear-gradient(135deg, ${theme.surfaceElevated}, ${theme.surface})`,
  border: `1px solid ${theme.gold}33`,
};

const miniStatsRowStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  marginTop: 16,
};

const tabsContainerStyle: CSSProperties = {
  display: 'flex',
  gap: 4,
  padding: 4,
  borderRadius: 16,
  background: theme.surfaceElevated,
  marginBottom: 16,
};

const tabButtonBaseStyle: CSSProperties = {
  flex: 1,
  padding: '10px 0',
  borderRadius: 12,
  cursor: 'pointer',
  fontSize: 13,
  fontFamily: fonts(),
  transition: 'all 0.2s ease',
};

function fonts(): string {
  return "'Inter', sans-serif";
}

const contentStyle: CSSProperties = {
  paddingBottom: 24,
};

const notificationStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 16,
  padding: 16,
  marginBottom: 12,
  borderRadius: 20,
  background: theme.surfaceElevated,
  border: '1px solid transparent',
};

const paymentStyle: CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 16,
  padding: '16px 20px',
  marginBottom: 12,
  borderRadius: 20,
  background: theme.surfaceElevated,
  border: `1px solid ${theme.gold}1A`,
};

const paymentIconStyle: CSSProperties = {
  width: 44,
  height: 44,
  borderRadius: 14,
  background: theme.deepBlack,
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
};

const emptyStyle: CSSProperties = {
  textAlign: 'center',
  color: theme.textSecondary,
  padding: '40px 0',
  fontSize: 14,
};

const fabStyle: CSSProperties = {
  position: 'fixed',
  bottom: 24,
  left: '50%',
  transform: 'translateX(-50%)',
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  padding: '16px 28px',
  borderRadius: 32,
  border: 'none',
  background: theme.gold,
  color: theme.deepBlack,
  fontSize: 16,
  fontWeight: 700,
  fontFamily: "'Inter', sans-serif",
  cursor: 'pointer',
  boxShadow: `0 8px 32px ${theme.gold}40`,
  transition: 'transform 0.2s ease, box-shadow 0.2s ease',
};

const statusBarStyle: CSSProperties = {
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  padding: '12px 20px',
  borderRadius: 16,
  background: theme.surfaceElevated,
  border: `1px solid ${theme.gold}55`,
  marginBottom: 16,
};

const overlayStyle: CSSProperties = {
  position: 'fixed',
  inset: 0,
  background: 'rgba(0,0,0,0.7)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  zIndex: 100,
};

const dialogStyle: CSSProperties = {
  background: theme.surfaceElevated,
  borderRadius: 24,
  padding: 28,
  width: '90%',
  maxWidth: 360,
  border: `1px solid ${theme.gold}33`,
};

const dialogOptionStyle: CSSProperties = {
  display: 'block',
  width: '100%',
  padding: '14px 16px',
  marginBottom: 8,
  borderRadius: 14,
  border: 'none',
  background: theme.surface,
  color: theme.textPrimary,
  fontSize: 15,
  fontFamily: "'Inter', sans-serif",
  textAlign: 'left',
  cursor: 'pointer',
  transition: 'background 0.15s ease',
};

const dialogCancelStyle: CSSProperties = {
  display: 'block',
  width: '100%',
  padding: '14px 16px',
  marginTop: 8,
  borderRadius: 14,
  border: 'none',
  background: 'transparent',
  color: theme.textSecondary,
  fontSize: 15,
  fontFamily: "'Inter', sans-serif",
  cursor: 'pointer',
};
