import copy, importlib.util, pathlib, shutil, tempfile, unittest
root=pathlib.Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('gtfs',root/'scripts/import_gtfs.py')
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)

class ImportTests(unittest.TestCase):
    def test_overnight_and_calendar_exception(self):
        t,meta=g.load_gtfs(root/'examples/gtfs','2026-10-31')
        self.assertEqual(len(t['trips']),3)
        self.assertEqual(t['trips'][0]['calls'][1]['arrival'],86400)
        self.assertEqual(t['stops'][1]['min_change'],120)
        self.assertEqual(meta['active_services'],['DAILY','SPECIAL'])
        t,_=g.load_gtfs(root/'examples/gtfs','2026-11-01')
        self.assertEqual(t['trips'],[])
    def fixture(self):
        temp=tempfile.TemporaryDirectory(prefix='tripfrontier-gtfs-')
        path=pathlib.Path(temp.name)/'feed';shutil.copytree(root/'examples/gtfs',path)
        self.addCleanup(temp.cleanup);return path
    def test_unsupported_semantics_are_rejected(self):
        for name,body in [('frequencies.txt','trip_id,start_time,end_time,headway_secs\nlocal,08:00:00,10:00:00,300\n'),
                          ('pathways.txt','pathway_id\nx\n')]:
            path=self.fixture();(path/name).write_text(body,encoding='utf-8')
            with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
    def test_on_demand_and_empty_times_reject(self):
        for before,after in [('A,10,0,0','A,10,2,0'),('23:50:00,23:50:00',',')]:
            path=self.fixture();p=path/'stop_times.txt';p.write_text(p.read_text(encoding='utf-8').replace(before,after),encoding='utf-8')
            with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
    def test_duplicate_csv_headers_and_stop_sequences_reject(self):
        path=self.fixture();p=path/'stops.txt';p.write_text('stop_id,stop_id\nA,A\n',encoding='utf-8')
        with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
        path=self.fixture();p=path/'stop_times.txt';s=p.read_text(encoding='utf-8');p.write_text(s+s.splitlines()[1]+'\n',encoding='utf-8')
        with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
    def test_transfers_do_not_invent_accessibility(self):
        path=self.fixture();p=path/'transfers.txt';p.write_text(p.read_text(encoding='utf-8')+'A,B,2,60\n',encoding='utf-8')
        t,_=g.load_gtfs(path,'2026-10-31');self.assertFalse(t['footpaths'][0]['accessible'])
    def test_unsupported_transfer_rules_reject(self):
        path=self.fixture();(path/'transfers.txt').write_text('from_stop_id,to_stop_id,transfer_type,min_transfer_time\nB,B,3,0\n',encoding='utf-8')
        with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
    def test_empty_stops_and_self_parent_reject(self):
        path=self.fixture();(path/'stops.txt').write_text('stop_id,stop_name\n',encoding='utf-8')
        with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')
        path=self.fixture();(path/'stops.txt').write_text('stop_id,stop_name,parent_station\nA,A,A\nB,B,\nD,D,\n',encoding='utf-8')
        with self.assertRaises(g.ImportError):g.load_gtfs(path,'2026-10-31')

if __name__=='__main__':unittest.main()
